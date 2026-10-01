import SwiftUI

// MARK: - AI consent

/// Asked once, before the first meal photo leaves the phone. App Store
/// guideline 5.1.2(i) requires explicit permission before personal data is
/// shared with a third-party AI.
struct AIConsentSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Runs after the person allows it (e.g. the estimate they asked for).
    var onAllow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            IconBadge(systemName: "sparkles", size: 48)

            Text("BEFORE WE ESTIMATE")
                .font(.flexDisplay(28))
                .foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 12) {
                point("photo", "This meal photo, plus any note or cuisine you've added, is sent to FlexUp's server and to Anthropic's Claude AI to estimate calories and macros.")
                point("trash", "FlexUp doesn't keep the photo, and Anthropic doesn't use it to train its models.")
                point("lock", "Nothing else leaves your phone. Your other logs, weight, runs and progress photos stay here.")
                point("slider.horizontal.3", "Change your mind any time in Profile → Privacy & data.")
            }

            if let url = BackendConfig.privacyPolicyURL {
                Button("Read the privacy policy") { openURL(url) }
                    .font(.flexCaption())
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            VStack(spacing: 10) {
                Button("Allow AI estimates") {
                    store.setAIPhotoConsent(true)
                    dismiss()
                    onAllow()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Not now") {
                    store.setAIPhotoConsent(false)
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(Theme.background)
        .presentationDetents([.large])
    }

    private func point(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Privacy & data

/// Everything about what leaves the phone, in one place: AI estimate
/// permission, the policy and terms, support, and account deletion.
struct PrivacyDataView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var confirmDelete = false
    @State private var deleteError: String?
    /// Fresh export file, written when the screen opens.
    @State private var exportURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlexCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR LOGS STAY ON YOUR PHONE")
                            .font(.flexMono(10))
                            .tracking(1.5)
                            .foregroundStyle(Theme.accent)
                        Text("Your account, wake-ups, sleep, runs and routes, workouts, food, weight and photos are stored only on this iPhone. The only thing that ever leaves it is a meal photo you ask FlexUp to estimate.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "AI photo estimates", subtitle: "Meal photos go to Anthropic's Claude only when you ask for an estimate.")
                    Toggle(isOn: Binding(
                        get: { store.aiPhotoConsent == true },
                        set: { store.setAIPhotoConsent($0) }
                    )) {
                        Label("Allow AI estimates", systemImage: "sparkles")
                            .font(.flexBody())
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.accent)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Your data", subtitle: "A copy of everything you've logged, as a JSON file you can keep or move.")
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            HStack(spacing: 14) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 22)
                                Text("Export my data")
                                    .font(.flexBody())
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .padding(14)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Couldn't prepare the export. Try again later.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }

                if BackendConfig.isConfigured {
                    VStack(spacing: 0) {
                        linkRow("Privacy policy", icon: "hand.raised", url: BackendConfig.privacyPolicyURL)
                        Divider().padding(.leading, 50)
                        linkRow("Terms of use", icon: "doc.text", url: BackendConfig.termsURL)
                        Divider().padding(.leading, 50)
                        linkRow("Help and support", icon: "questionmark.circle", url: BackendConfig.supportURL)
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if store.isSignedIn {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Delete account", role: .destructive) { confirmDelete = true }
                            .buttonStyle(SecondaryButtonStyle(tint: Theme.danger))
                        if let deleteError {
                            Text(deleteError)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.danger)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Privacy & data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            exportURL = try? store.exportData()
        }
        .confirmationDialog("Delete your FlexUp account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { @MainActor in
                    do {
                        try await store.deleteAccount()
                        deleteError = nil
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
            Button("Keep my account", role: .cancel) {}
        } message: {
            Text(store.community.isSignedIn
                 ? "This permanently deletes your FlexUp account and all of your data, on our server and on this phone. It can't be undone."
                 : "This permanently deletes your account and every log, photo and reminder on this phone. It can't be undone.")
        }
    }

    private func linkRow(_ title: String, icon: String, url: URL?) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
                Text(title)
                    .font(.flexBody())
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSubtle)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
