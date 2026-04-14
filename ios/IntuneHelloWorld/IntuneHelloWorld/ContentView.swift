//
//  ContentView.swift
//  IntuneHelloWorld
//
//  Created by Anthony Pham on 4/14/26.
//

import SwiftUI
import IntuneMAMSwift

struct ContentView: View {

    @State private var auth = AuthManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                StatusCard(auth: auth)

                if auth.isEnrolled {
                    ManagedConfigCard(entries: auth.managedConfig)
                }

                Spacer()

                if auth.userUPN == nil {
                    Button {
                        Task { await auth.signIn() }
                    } label: {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Label("Sign in with Microsoft", systemImage: "person.badge.key")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(auth.isLoading)
                } else {
                    Button(role: .destructive, action: auth.signOut) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Intune Hello World")
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let auth: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Label("MAM Status", systemImage: "shield.lefthalf.filled")
                .font(.headline)

            Divider()

            row("User", value: auth.userUPN ?? "Not signed in")
            row("Enrollment", value: auth.enrollmentStatus)
            row("Policies Active", value: auth.isEnrolled ? "Yes" : "No")
            row("SDK Version", value: IntuneMAMVersionInfo.sdkVersion() ?? "Unknown")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
    }
}

// MARK: - Managed Config Card

struct ManagedConfigCard: View {
    let entries: [(key: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Label("Managed App Config", systemImage: "gearshape.2")
                .font(.headline)

            Divider()

            if entries.isEmpty {
                Text("No config pushed from Intune yet.\nAn IT admin can push key-value pairs from the Intune console.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.key) { entry in
                    HStack {
                        Text(entry.key)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.value)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
