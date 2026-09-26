import SwiftUI
import AuthenticationServices

enum AccountMode: String, CaseIterable, Identifiable {
    case create = "Sign up"
    case login = "Log in"
    var id: String { rawValue }
}

// MARK: - Full-screen pages (front door)

/// The sign-up or log-in page pushed from `AuthView`: big title, the form,
/// and a link across to the other page.
struct AccountPage: View {
    @Environment(AppStore.self) private var store
    let mode: AccountMode
    var onSignedIn: (CommunityMe, AuthProvider) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(mode == .create ? "CREATE YOUR\nACCOUNT" : "WELCOME\nBACK")
                        .font(.flexDisplay(40))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent)
                            .frame(width: 22, height: 3)
                        Text(mode == .create ? "ONE ACCOUNT FOR YOU AND YOUR CREW." : "PICK UP WHERE YOU LEFT OFF.")
                            .font(.flexMono(11))
                            .tracking(2)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                .padding(.top, 10)

                AccountForm(mode: mode, onSignedIn: onSignedIn)

                NavigationLink(value: mode == .create ? AccountMode.login : AccountMode.create) {
                    Text(mode == .create ? "ALREADY HAVE AN ACCOUNT? LOG IN" : "NEW HERE? CREATE AN ACCOUNT")
                        .font(.flexMono(10))
                        .tracking(1.5)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sheet (connect later, from inside the app)

/// For people who set up FlexUp before accounts were real: create one or
/// log in without leaving the screen they're on.
struct CommunityAuthSheet: View {
    typealias Mode = AccountMode

    var initialMode: AccountMode = .create
    var onSignedIn: (CommunityMe, AuthProvider) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: AccountMode = .create

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
                    SegmentPills(items: AccountMode.allCases, selection: $mode)
                    AccountForm(mode: mode) { me, provider in
                        onSignedIn(me, provider)
                        dismiss()
                    }
                    .id(mode)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear { mode = initialMode }
    }
}

// MARK: - The form

/// Email + password (with name and guidelines on sign-up) or Sign in with
/// Apple, against the FlexUp server.
struct AccountForm: View {
    let mode: AccountMode
    var onSignedIn: (CommunityMe, AuthProvider) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreed = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var showGuidelines = false

    private var emailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 6
    }

    private var canSubmit: Bool {
        guard emailValid, !isWorking else { return false }
        if mode == .login { return !password.isEmpty }
        return password.count >= 8 && !name.trimmingCharacters(in: .whitespaces).isEmpty && agreed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode == .create {
                field("NAME") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                }
            }
            field("EMAIL") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            field("PASSWORD") {
                SecureField(mode == .create ? "8+ characters" : "Your password", text: $password)
                    .textContentType(mode == .create ? .newPassword : .password)
            }

            if mode == .create {
                Button {
                    agreed.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: agreed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(agreed ? Theme.accent : Theme.inkSubtle)
                        Text("I agree to the community guidelines: be kind, keep it real, no harassment, hate or explicit content.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                Button("Read the guidelines") { showGuidelines = true }
                    .font(.flexCaption())
                    .foregroundStyle(Theme.accent)
            }

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

            SignInWithAppleButton(mode == .create ? .signUp : .signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await apple(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule())
            .disabled(isWorking)
        }
        .sheet(isPresented: $showGuidelines) {
            GuidelinesSheet()
        }
        .onAppear {
            if name.isEmpty { name = store.profile?.name ?? store.account?.name ?? "" }
            if email.isEmpty { email = store.account?.email ?? "" }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.flexMono(9))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSubtle)
            content()
                .font(.flexBodyBold())
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
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
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Guidelines

/// What everyone agrees to at sign-up. Apple requires apps with posts and
/// messages to have terms, a filter, reporting and blocking — this is the
/// terms part, in plain words.
struct GuidelinesSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let rules: [(String, String)] = [
        ("Be kind", "Cheer people on. Criticism of effort has no place here."),
        ("Keep it real", "Post what you actually did. No fake progress, no spam, no selling."),
        ("Zero tolerance", "No harassment, bullying, hate, threats, sexual or violent content. Accounts that break this are removed."),
        ("Protect privacy", "Don't share other people's photos or details without their OK."),
        ("Report, block, move on", "Use ⋯ → Report on anything that crosses the line — we review reports within 24 hours. Block anyone, any time."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(rules, id: \.0) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.0.uppercased())
                                .font(.flexMono(11))
                                .tracking(1.5)
                                .foregroundStyle(Theme.accent)
                            Text(rule.1)
                                .font(.flexBody())
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Community guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
