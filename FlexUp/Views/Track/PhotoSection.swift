import SwiftUI
import UIKit
import PhotosUI

/// Progress pictures with pose guides. Same pose, same spot, over and over —
/// the most honest progress graph there is.
struct PhotoSection: View {
    @Environment(AppStore.self) private var store
    @State private var showCapture = false
    @State private var filter: PhotoPose = .front

    private var filtered: [ProgressPhoto] {
        store.photos(for: filter).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            compareCard

            Button {
                showCapture = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                    Text("New progress photo")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Timeline")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(PhotoPose.allCases) { pose in
                            SelectableChip(label: pose.label, icon: pose.icon, isSelected: filter == pose) {
                                filter = pose
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if filtered.isEmpty {
                    EmptyStateCard(
                        icon: "camera",
                        title: "No \(filter.label.lowercased()) photos yet",
                        message: filter == .proof
                            ? "Photo-verified completions land here automatically."
                            : "Day one is the photo you'll be gladdest you took."
                    )
                } else {
                    photoGrid
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            PoseCaptureSheet()
        }
    }

    // MARK: Compare

    private var compareCard: some View {
        let photos = store.photos(for: filter)
        return Group {
            if photos.count >= 2, let first = photos.first, let latest = photos.last {
                FlexCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THEN VS NOW — \(filter.label.uppercased())")
                            .font(.flexMono(10))
                            .tracking(2)
                            .foregroundStyle(Theme.accent)
                        HStack(spacing: 10) {
                            comparePane(first, caption: "DAY ONE")
                            comparePane(latest, caption: "LATEST")
                        }
                    }
                }
            }
        }
    }

    private func comparePane(_ photo: ProgressPhoto, caption: String) -> some View {
        VStack(spacing: 6) {
            PhotoThumb(photo: photo)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("\(caption) · \(photo.date.formatted(.dateTime.day().month()).uppercased())")
                .font(.flexMono(9))
                .tracking(1)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Grid

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    private var photoGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(filtered) { photo in
                PhotoThumb(photo: photo)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text(photo.date.formatted(.dateTime.day().month()).uppercased())
                            .font(.flexMono(8))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.45))
                            .clipShape(Capsule())
                            .padding(5)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteProgressPhoto(photo)
                        } label: {
                            Label("Delete photo", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

// MARK: - Thumbnail

struct PhotoThumb: View {
    @Environment(AppStore.self) private var store
    let photo: ProgressPhoto
    var maxPixel: CGFloat = 500

    var body: some View {
        AsyncPhotoView(url: store.imageURL(for: photo), maxPixel: maxPixel)
    }
}

// MARK: - Pose capture

struct PoseCaptureSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var pose: PhotoPose = .front
    @State private var showCamera = false
    @State private var showLibrary = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("PICK YOUR POSE")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 170, height: 170)
                Image(systemName: pose.icon)
                    .font(.system(size: 84, weight: .light))
                    .foregroundStyle(Theme.accent)
            }
            .animation(.spring(duration: 0.25), value: pose)

            Text("Match the pose. Same spot, same light, every time — that's what makes the comparison honest.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            HStack(spacing: 8) {
                ForEach(PhotoPose.captureCases) { item in
                    SelectableChip(label: item.label, icon: item.icon, isSelected: pose == item) {
                        pose = item
                    }
                }
            }

            Spacer()

            VStack(spacing: 10) {
                if cameraAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Open camera", systemImage: "camera")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Button {
                    showLibrary = true
                } label: {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(cameraAvailable ? SecondaryButtonStyle() : SecondaryButtonStyle(tint: Theme.background, background: Theme.ink))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                savePhoto(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { image in
                savePhoto(image)
            }
        }
    }

    private func savePhoto(_ image: UIImage) {
        guard let data = image.flexJPEGData() else { return }
        store.addProgressPhoto(imageData: data, pose: pose)
        dismiss()
    }
}

// MARK: - Camera (UIImagePickerController)

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Library (PHPicker — no permission prompt needed)

struct LibraryPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPicker
        init(_ parent: LibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.parent.onImage(image)
                    }
                    self.parent.dismiss()
                }
            }
        }
    }
}
