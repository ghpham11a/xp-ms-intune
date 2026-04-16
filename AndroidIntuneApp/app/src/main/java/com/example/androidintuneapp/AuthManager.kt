package com.example.androidintuneapp

import android.app.Activity
import android.app.Application
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.microsoft.identity.client.AcquireTokenSilentParameters
import com.microsoft.identity.client.AuthenticationCallback
import com.microsoft.identity.client.IAccount
import com.microsoft.identity.client.IAuthenticationResult
import com.microsoft.identity.client.IPublicClientApplication
import com.microsoft.identity.client.ISingleAccountPublicClientApplication
import com.microsoft.identity.client.Prompt
import com.microsoft.identity.client.PublicClientApplication
import com.microsoft.identity.client.SignInParameters
import com.microsoft.identity.client.exception.MsalException
import com.microsoft.intune.mam.client.app.MAMComponents
import com.microsoft.intune.mam.client.notification.MAMNotificationReceiver
import com.microsoft.intune.mam.client.notification.MAMNotificationReceiverRegistry
import com.microsoft.intune.mam.policy.MAMEnrollmentManager
import com.microsoft.intune.mam.policy.MAMServiceAuthenticationCallback
import com.microsoft.intune.mam.policy.appconfig.MAMAppConfig
import com.microsoft.intune.mam.policy.appconfig.MAMAppConfigManager
import com.microsoft.intune.mam.policy.notification.MAMEnrollmentNotification
import com.microsoft.intune.mam.policy.notification.MAMNotification
import com.microsoft.intune.mam.policy.notification.MAMNotificationType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Kotlin/Android counterpart of the iOS `AuthManager`: runs MSAL sign-in, hands
 * the resulting account to the Intune MAM SDK for enrollment, and listens for
 * enrollment/wipe/app-config notifications.
 */
class AuthManager(application: Application) : AndroidViewModel(application) {

    // --- Observable UI state (consumed by Compose via `by remember { ... }` on the VM). ---

    var userUpn by mutableStateOf<String?>(null)
        private set
    var isEnrolled by mutableStateOf(false)
        private set
    var enrollmentStatus by mutableStateOf("Not started")
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set

    /** Flattened `MAMAppConfig.fullData` for display — mirrors iOS `mamAppConfig`. */
    val mamAppConfig = mutableStateListOf<Pair<String, String>>()

    // --- MSAL + MAM wiring ---

    private var msalApp: ISingleAccountPublicClientApplication? = null
    private var cachedAccount: IAccount? = null

    private val enrollmentManager: MAMEnrollmentManager? =
        MAMComponents.get(MAMEnrollmentManager::class.java)
    private val appConfigManager: MAMAppConfigManager? =
        MAMComponents.get(MAMAppConfigManager::class.java)
    private val notificationRegistry: MAMNotificationReceiverRegistry? =
        MAMComponents.get(MAMNotificationReceiverRegistry::class.java)

    private val enrollmentReceiver = MAMNotificationReceiver { notification ->
        handleEnrollmentNotification(notification)
        true
    }
    private val appConfigReceiver = MAMNotificationReceiver { _ ->
        refreshAppConfig()
        true
    }
    private val wipeReceiver = MAMNotificationReceiver { _ ->
        handleWipe()
        true
    }

    init {
        setupMsal()
        registerMamReceivers()
    }

    // region MSAL

    private fun setupMsal() {
        isLoading = true
        PublicClientApplication.createSingleAccountPublicClientApplication(
            getApplication<Application>(),
            R.raw.msal_config,
            object : IPublicClientApplication.ISingleAccountApplicationCreatedListener {
                override fun onCreated(app: ISingleAccountPublicClientApplication) {
                    msalApp = app
                    enrollmentManager?.registerAuthenticationCallback(MamAuthCallback())
                    Log.i(TAG, "✅ MSAL configured")
                    restoreSignedInState()
                    isLoading = false
                }

                override fun onError(exception: MsalException) {
                    errorMessage = "MSAL setup failed: ${exception.message}"
                    Log.e(TAG, "❌ MSAL setup error", exception)
                    isLoading = false
                }
            }
        )
    }

    private fun restoreSignedInState() {
        val app = msalApp ?: return
        app.getCurrentAccountAsync(object : ISingleAccountPublicClientApplication.CurrentAccountCallback {
            override fun onAccountLoaded(activeAccount: IAccount?) {
                if (activeAccount == null) return
                cachedAccount = activeAccount
                userUpn = activeAccount.username
                // MAM may have persisted enrollment across app launches.
                val status = enrollmentManager
                    ?.getRegisteredAccountStatus(activeAccount.username, activeAccount.id)
                if (status == MAMEnrollmentManager.Result.ENROLLMENT_SUCCEEDED) {
                    isEnrolled = true
                    enrollmentStatus = "\u2705 Enrolled — policies active"
                    refreshAppConfig()
                }
                Log.i(TAG, "♻\uFE0F Restored account ${activeAccount.username}, MAM status=$status")
            }

            override fun onAccountChanged(prior: IAccount?, current: IAccount?) = Unit
            override fun onError(exception: MsalException) {
                Log.w(TAG, "getCurrentAccount failed", exception)
            }
        })
    }

    fun signIn(activity: Activity) {
        val app = msalApp
        if (app == null) {
            errorMessage = "MSAL is not configured."
            return
        }

        isLoading = true
        errorMessage = null
        enrollmentStatus = "Signing in..."

        val params = SignInParameters.builder()
            .withActivity(activity)
            .withScopes(listOf("User.Read"))
            .withPrompt(Prompt.SELECT_ACCOUNT)
            .withCallback(interactiveCallback())
            .build()
        app.signIn(params)
    }

    private fun interactiveCallback() = object : AuthenticationCallback {
        override fun onSuccess(result: IAuthenticationResult) {
            val account = result.account
            cachedAccount = account
            userUpn = account.username
            Log.i(TAG, "\uD83D\uDC64 signed in — upn=${account.username} oid=${account.id}")
            registerForMam(account)
            isLoading = false
        }

        override fun onError(exception: MsalException) {
            errorMessage = exception.message
            enrollmentStatus = "Sign in failed"
            isLoading = false
            Log.e(TAG, "MSAL sign-in error", exception)
        }

        override fun onCancel() {
            enrollmentStatus = "Sign in cancelled"
            isLoading = false
        }
    }

    // endregion

    // region MAM enrollment

    private fun registerForMam(account: IAccount) {
        val mgr = enrollmentManager ?: run {
            errorMessage = "Intune MAM SDK unavailable"
            return
        }

        val alreadyEnrolled = mgr.getRegisteredAccountStatus(account.username, account.id) ==
            MAMEnrollmentManager.Result.ENROLLMENT_SUCCEEDED
        if (alreadyEnrolled) {
            isEnrolled = true
            enrollmentStatus = "\u2705 Enrolled — policies active"
            refreshAppConfig()
            Log.i(TAG, "♻\uFE0F Already enrolled as ${account.id} — skipping register call")
            return
        }

        enrollmentStatus = "Enrolling with Intune..."
        mgr.registerAccountForMAM(
            account.username,
            account.id,
            account.tenantId,
            account.authority,
        )
    }

    fun signOut() {
        val app = msalApp ?: return
        val account = cachedAccount

        if (account != null) {
            enrollmentManager?.unregisterAccountForMAM(account.username, account.id)
        }

        app.signOut(object : ISingleAccountPublicClientApplication.SignOutCallback {
            override fun onSignOut() {
                cachedAccount = null
                userUpn = null
                isEnrolled = false
                enrollmentStatus = "Signed out"
                mamAppConfig.clear()
            }

            override fun onError(exception: MsalException) {
                errorMessage = "Sign out error: ${exception.message}"
            }
        })
    }

    // endregion

    // region MAM notifications + app config

    private fun registerMamReceivers() {
        val registry = notificationRegistry ?: return
        registry.registerReceiver(enrollmentReceiver, MAMNotificationType.MAM_ENROLLMENT_RESULT)
        registry.registerReceiver(appConfigReceiver, MAMNotificationType.REFRESH_APP_CONFIG)
        registry.registerReceiver(wipeReceiver, MAMNotificationType.WIPE_USER_DATA)
    }

    private fun handleEnrollmentNotification(notification: MAMNotification) {
        val enroll = notification as? MAMEnrollmentNotification ?: return
        val result = enroll.enrollmentResult
        Log.i(TAG, "\uD83D\uDCE3 enrollment notification — result=$result identity=${enroll.userIdentity}")
        viewModelScope.launch(Dispatchers.Main) {
            when (result) {
                MAMEnrollmentManager.Result.ENROLLMENT_SUCCEEDED -> {
                    isEnrolled = true
                    enrollmentStatus = "\u2705 Enrolled — policies active"
                    refreshAppConfig()
                }
                MAMEnrollmentManager.Result.UNENROLLMENT_SUCCEEDED -> {
                    isEnrolled = false
                    enrollmentStatus = "Unenrolled"
                    mamAppConfig.clear()
                }
                MAMEnrollmentManager.Result.AUTHORIZATION_NEEDED,
                MAMEnrollmentManager.Result.NOT_LICENSED,
                MAMEnrollmentManager.Result.PENDING,
                MAMEnrollmentManager.Result.COMPANY_PORTAL_REQUIRED -> {
                    enrollmentStatus = "\u23F3 ${result.name.replace('_', ' ')}"
                }
                MAMEnrollmentManager.Result.ENROLLMENT_FAILED,
                MAMEnrollmentManager.Result.UNENROLLMENT_FAILED,
                MAMEnrollmentManager.Result.WRONG_USER -> {
                    isEnrolled = false
                    enrollmentStatus = "\u274C ${result.name.replace('_', ' ')}"
                    errorMessage = "Enrollment error: ${result.name}"
                }
                else -> enrollmentStatus = result?.name ?: "Unknown"
            }
        }
    }

    private fun handleWipe() {
        viewModelScope.launch(Dispatchers.Main) {
            cachedAccount = null
            userUpn = null
            isEnrolled = false
            enrollmentStatus = "Wiped by admin"
            mamAppConfig.clear()
        }
    }

    private fun refreshAppConfig() {
        val mgr = appConfigManager ?: return
        val account = cachedAccount ?: return
        viewModelScope.launch(Dispatchers.Main) {
            val appConfig: MAMAppConfig? = mgr.getAppConfigForOID(account.id)
            val dicts: List<Map<String, String>> = appConfig?.fullData ?: emptyList()

            val merged = linkedMapOf<String, MutableList<String>>()
            dicts.forEach { dict ->
                dict.forEach { (k, v) ->
                    merged.getOrPut(k) { mutableListOf() }.add(v)
                }
            }
            mamAppConfig.clear()
            merged.toSortedMap().forEach { (k, vs) ->
                mamAppConfig.add(k to vs.joinToString(", "))
            }
            Log.i(TAG, "\uD83E\uDDE9 MAM app config refreshed — ${mamAppConfig.size} key(s)")
        }
    }

    // endregion

    override fun onCleared() {
        super.onCleared()
        val registry = notificationRegistry ?: return
        registry.unregisterReceiver(enrollmentReceiver, MAMNotificationType.MAM_ENROLLMENT_RESULT)
        registry.unregisterReceiver(appConfigReceiver, MAMNotificationType.REFRESH_APP_CONFIG)
        registry.unregisterReceiver(wipeReceiver, MAMNotificationType.WIPE_USER_DATA)
    }

    /**
     * Supplies fresh AAD tokens to the MAM SDK on demand. The SDK calls this on
     * a background thread, so a blocking silent MSAL call is the idiomatic
     * approach.
     */
    private inner class MamAuthCallback : MAMServiceAuthenticationCallback {
        override fun acquireToken(upn: String, aadId: String, resourceId: String): String? {
            val app = msalApp ?: return null
            val account = cachedAccount ?: return null
            if (account.id != aadId) return null

            return try {
                val params = AcquireTokenSilentParameters.Builder()
                    .forAccount(account)
                    .fromAuthority(account.authority)
                    .withScopes(listOf("$resourceId/.default"))
                    .build()
                app.acquireTokenSilent(params).accessToken
            } catch (e: Exception) {
                Log.w(TAG, "silent MAM token failed for $aadId", e)
                null
            }
        }
    }

    companion object {
        private const val TAG = "AuthManager"
    }
}
