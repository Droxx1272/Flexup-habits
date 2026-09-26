import SwiftUI
import AuthenticationServices

/// The front door. With cloud accounts on (`FeatureFlags.cloudAccounts`)
/// accounts live on the FlexUp server. Otherwise the account lives on this
/// phone: Sign in with Apple or a name and email.
struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEmailForm = false
    @State private var authError: String?

    var body: some View {
        NavigationStack {
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
                    if BackendConfig.isConfigured && FeatureFlags.cloudAccounts {
                        NavigationLink(value: AccountMode.create) {
                            Text("Create account")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        NavigationLink(value: AccountMode.login) {
                            Text("Log in")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button("Continue with email") {
                            showEmailForm = true
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 54)
                        .clipShape(Capsule())
                    }

                    if let authError {
                        Text(authError)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                    }

                    Text(FeatureFlags.cloudAccounts && FeatureFlags.community
                         ? "YOUR LOGS STAY ON YOUR PHONE. FRIENDS SEE ONLY WHAT YOU SHARE."
                         : "YOUR LOGS STAY ON YOUR PHONE.")
                        .font(.flexMono(9))
                        .tracking(1.5)
                        .foregroundStyle(Theme.inkSubtle)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AccountMode.self) { mode in
                AccountPage(mode: mode) { me, provider in
                    signIn(me, provider: provider)
                }
            }
        }
        .tint(Theme.ink)
        .sheet(isPresented: $showEmailForm) {
            EmailSignInSheet()
        }
    }

    private func signIn(_ me: CommunityMe, provider: AuthProvider) {
        store.signIn(Account(userID: me.id, name: me.name, email: me.email, provider: provider))
    }

    /// On-device account, used while cloud accounts are off.
    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Couldn't read the Apple credential. Try email instead."
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
            authError = "Apple sign-in isn't set up on this build yet. Use email instead."
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

            Text("Your account and logs stay on this phone. Log back in with the same email and everything is still here.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Button("Continue") {
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
