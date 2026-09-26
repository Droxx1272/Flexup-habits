import SwiftUI
import UIKit

/// Your own avatar, wherever it appears: the server photo when community is
/// on and you've set one, otherwise the photo saved on this phone, otherwise
/// your initials.
struct MyAvatar: View {
    @Environment(AppStore.self) private var store
    var size: CGFloat = 40
    var ring = false

    private var name: String {
        store.profile?.name ?? store.account?.name ?? ""
    }

    var body: some View {
        if FeatureFlags.community, let me = store.community.me, me.avatarId != nil {
            ProfileAvatar(name: me.name, avatarId: me.avatarId, size: size, ring: ring)
        } else if let url = store.profilePhotoURL {
            AsyncPhotoView(url: url, maxPixel: size * 3)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .padding(ring ? max(2, size * 0.035) : 0)
                .overlay {
                    if ring {
                        Circle().strokeBorder(ProfileAvatar.ringGradient, lineWidth: max(2, size * 0.03))
                    }
                }
        } else {
            ProfileAvatar(name: name, avatarId: nil, size: size, ring: ring)
        }
    }
}

/// Big avatar with the camera badge: take a photo, pick one, or remove it.
struct ProfilePhotoEditor: View {
    @Environment(AppStore.self) private var store
    var size: CGFloat = 150

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isSaving = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MyAvatar(size: size, ring: true)
                .overlay {
                    if isSaving {
                        ProgressView()
                            .padding(20)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                }

            Menu {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take photo", systemImage: "camera") { showCamera = true }
                }
                Button("Choose from library", systemImage: "photo.on.rectangle") { showLibrary = true }
                if store.profilePhotoURL != nil {
                    Button("Remove photo", systemImage: "trash", role: .destructive) {
                        store.setProfilePhoto(nil)
                    }
                }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: size * 0.11, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(width: size * 0.29, height: size * 0.29)
                    .background(Theme.ink)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.background, lineWidth: 4))
            }
            .accessibilityLabel("Change profile photo")
            .offset(x: -size * 0.02, y: -size * 0.02)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in save(image) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { image in save(image) }
        }
    }

    private func save(_ image: UIImage) {
        guard let data = image.flexJPEGData(maxEdge: 800, quality: 0.8) else { return }
        store.setProfilePhoto(data)
        // With community on, friends see the same photo.
        guard FeatureFlags.community, store.community.isSignedIn else { return }
        let community = store.community
        Task { @MainActor in
            isSaving = true
            defer { isSaving = false }
            try? await community.setAvatar(image)
        }
    }
}

/// Edit the name and "becoming…" line on this phone.
struct LocalProfileEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var identity = ""

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                field("NAME") {
                    TextField("Your name", text: $name)
                        .textContentType(.givenName)
                }
                field("BECOMING") {
                    TextField("an early riser", text: $identity)
                }
                Text("Shown on your profile and in the app's greetings.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateProfile(name: name, identity: identity)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                name = store.profile?.name ?? ""
                identity = store.profile?.identityStatement ?? ""
            }
        }
        .presentationDetents([.medium])
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
}
