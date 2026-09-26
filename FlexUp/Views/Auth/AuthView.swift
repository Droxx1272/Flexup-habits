import SwiftUI
import AuthenticationServices

/// The front door. With the FlexUp server connected, accounts are real:
/// Sign in with Apple or email + password, the same account your friends
/// add. Without a server (early development builds) it falls back to an
/// on-device account so the rest of the app still works.
struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEmailForm = false
    @State private var showAccountSheet = false
    @State private var accountSheetMode: CommunityAuthSheet.Mode = .create
    @State private var authError: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.accent)
                Text("FLEXUP")
                    .font(.flexDisplay(52))
                    .foregroundStyle(Theme.ink)
                Text("WAKE. RUN. LIFT. FUEL.\nBECOME WHO YOU SAID YOU'D BE.")
                    .font(.flexMono(13))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                    .lineSpacing(6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    if BackendConfig.isConfigured {
                        Task { await handleServerApple(result) }
                    } else {
                        handleApple(result)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(Capsule())
                .disabled(isWorking)

                if BackendConfig.isConfigured {
                    Button("Create account with email") {
                        accountSheetMode = .create
                        showAccountSheet = true
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        accountSheetMode = .login
                        showAccountSheet = true
                    } label: {
                        Text("I HAVE AN ACCOUNT — LOG IN")
                            .font(.flexMono(10))
                            .tracking(1.5)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                } else {
                    Button("Continue with email") {
                        showEmailForm = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if let authError {
                    Text(authError)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }

                Text(BackendConfig.isConfigured
                     ? "YOUR LOGS STAY ON YOUR PHONE. FRIENDS SEE ONLY WHAT YOU SHARE."
                     : "YOUR DATA STAYS ON YOUR DEVICE.")
                    .font(.flexMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .sheet(isPresented: $showEmailForm) {
            EmailSignInSheet()
        }
        .sheet(isPresented: $showAccountSheet) {
            CommunityAuthSheet(initialMode: accountSheetMode) { me, provider in
                signIn(me, provider: provider)
            }
        }
    }

    private func signIn(_ me: CommunityMe, provider: AuthProvider) {
        store.signIn(Account(userID: me.id, name: me.name, email: me.email, provider: provider))
    }

    @MainActor
    private func handleServerApple(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            if case .failure(let error) = result, (error as? ASAuthorizationError)?.code == .canceled { return }
            authError = "Apple sign-in isn't available on this build — use email below."
            return
        }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        isWorking = true
        authError = nil
        defer { isWorking = false }
        do {
            let me = try await store.community.signInWithApple(identityToken: identityToken, name: fullName)
            signIn(me, provider: .apple)
        } catch {
            authError = error.localizedDescription
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Couldn't read the Apple credential — try email instead."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            store.signIn(Account(
                userID: credential.user,
                name: fullName.isEmpty ? "" : fullName,
                email: credential.email,
                provider: .apple
            ))
        case .failure:
            // Most common cause in development: the Sign In with Apple
            // capability isn't enabled for this build. Email still works.
            authError = "Apple sign-in isn't available on this build — continue with email below."
        }
    }
}

// MARK: - Email fallback

struct EmailSignInSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""

    private var emailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 6
    }

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && emailValid
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("CONTINUE WITH EMAIL")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)

            TextField("Name", text: $name)
                .font(.flexBodyBold())
                .textContentType(.name)
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("Email", text: $email)
                .font(.flexBodyBold())
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("This creates an account on this device. Verification and sync arrive with the FlexUp backend.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Button("Create account") {
                store.signIn(Account(
                    userID: "email:\(email.trimmingCharacters(in: .whitespaces).lowercased())",
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    provider: .email
                ))
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.background)
        .presentationDetents([.medium])
    }
}

#Preview {
    AuthView()
        .environment(AppStore())
}
