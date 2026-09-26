import SwiftUI
import AuthenticationServices

/// Create an account or log in on the FlexUp server — email + password or
/// Sign in with Apple. Used by the front door (`AuthView`) and by the
/// Friends screen for people who set up the app before accounts were real.
struct CommunityAuthSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case create = "Create account"
        case login = "Log in"
        var id: String { rawValue }
    }

    var initialMode: Mode = .create
    /// Called after the server accepts the sign-in, before the sheet closes.
    var onSignedIn: (CommunityMe, AuthProvider) -> Void = { _, _ in }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var mode: Mode = .create
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorText: String?

    private var emailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 6
    }

    private var canSubmit: Bool {
        guard emailValid, password.count >= (mode == .create ? 8 : 1), !isWorking else { return false }
        return mode == .login || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(mode == .create ? "JOIN YOUR CREW" : "WELCOME BACK")
                        .font(.flexMono(12))
                        .tracking(2)
                        .foregroundStyle(Theme.ink)
                    Text("One account keeps your progress yours and lets friends hold you to it.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)

                    SegmentPills(items: Mode.allCases, selection: $mode)

                    if mode == .create {
                        field("Name", text: $name)
                            .textContentType(.name)
                    }
                    field("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(mode == .create ? "Password (8+ characters)" : "Password", text: $password)
                        .textContentType(mode == .create ? .newPassword : .password)
                        .font(.flexBodyBold())
                        .padding(14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let errorText {
                        Text(errorText)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.danger)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isWorking { ProgressView().controlSize(.small).tint(Theme.background) }
                            Text(mode == .create ? "Create account" : "Log in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.4)

                    HStack {
                        Rectangle().fill(Theme.inkSubtle.opacity(0.2)).frame(height: 1)
                        Text("OR")
                            .font(.flexMono(9))
                            .tracking(1.5)
                            .foregroundStyle(Theme.inkSubtle)
                        Rectangle().fill(Theme.inkSubtle.opacity(0.2)).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await apple(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .disabled(isWorking)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear {
            mode = initialMode
            if name.isEmpty { name = store.profile?.name ?? store.account?.name ?? "" }
            if email.isEmpty { email = store.account?.email ?? "" }
        }
        .onChange(of: mode) { _, _ in errorText = nil }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.flexBodyBold())
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @MainActor
    private func submit() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        let cleanEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            let me: CommunityMe
            if mode == .create {
                me = try await store.community.signUp(
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: cleanEmail,
                    password: password
                )
            } else {
                me = try await store.community.logIn(email: cleanEmail, password: password)
            }
            onSignedIn(me, .email)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func apple(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            if case .failure(let error) = result, (error as? ASAuthorizationError)?.code == .canceled { return }
            errorText = "Apple sign-in isn't available on this build — use email instead."
            return
        }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            let me = try await store.community.signInWithApple(
                identityToken: identityToken,
                name: fullName.isEmpty ? (store.profile?.name ?? "") : fullName
            )
            onSignedIn(me, .apple)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
