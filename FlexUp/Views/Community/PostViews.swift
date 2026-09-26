import SwiftUI
import UIKit

// MARK: - Post card

/// One post in the feed: who, when, what they said, their photo, kudos and
/// comments. The ⋯ menu deletes your own posts or reports / blocks others.
struct PostCard: View {
    @Environment(AppStore.self) private var store
    let post: Post
    /// False on the post's own screen, where comments are already showing.
    var showsCommentLink = true
    var onKudos: () -> Void

    @State private var reporting = false
    @State private var reported = false
    @State private var confirmDelete = false
    @State private var confirmBlock = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !post.text.isEmpty {
                Text(post.text)
                    .font(.flexBody())
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if post.imageId != nil {
                RemoteImageView(url: store.community.imageURL(post.imageId), maxPixel: 1200)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 18) {
                Button(action: onKudos) {
                    Label(post.gaveKudos ? "Kudos" : "Give kudos", systemImage: post.gaveKudos ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.flexCaption())
                        .foregroundStyle(post.gaveKudos ? Theme.accent : Theme.ink)
                }
                .buttonStyle(.plain)
                .disabled(post.isMine)
                .opacity(post.isMine ? 0.35 : 1)

                if showsCommentLink {
                    NavigationLink(value: CommunityDestination.post(post)) {
                        Label(post.commentCount == 0 ? "Comment" : "\(post.commentCount)", systemImage: "bubble.right")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if !post.kudos.isEmpty {
                    AvatarStack(names: post.kudos.map(\.name), size: 22, maxShown: 3)
                }
            }

            if !post.kudos.isEmpty {
                Text(kudosLine)
                    .font(.flexMono(9))
                    .tracking(0.5)
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .confirmationDialog("Why are you reporting this?", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    Task {
                        try? await store.community.report(type: "post", id: post.id, reason: reason)
                        reported = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Thanks for telling us", isPresented: $reported) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We review every report within 24 hours. You can also block \(post.user.name) from the ⋯ menu.")
        }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete post", role: .destructive) {
                Task { await store.community.deletePost(post) }
            }
        }
        .confirmationDialog("Block \(post.user.name)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task { await store.community.block(post.user, day: store.todayKey) }
            }
        } message: {
            Text("You'll stop seeing each other's posts and activity, and they can't message or add you. They won't be told.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            NavigationLink(value: CommunityDestination.profile(post.user.id)) {
                HStack(spacing: 10) {
                    ProfileAvatar(user: post.user, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.isMine ? "You" : post.user.name)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        Text(post.createdAt.formatted(.relative(presentation: .named)).uppercased())
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                if post.isMine {
                    Button("Delete post", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } else {
                    Button("Report post", systemImage: "flag") { reporting = true }
                    Button("Block \(post.user.name)", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSubtle)
                    .frame(width: 32, height: 32)
            }
        }
    }

    private var kudosLine: String {
        let names = post.kudos.map { $0.id == store.community.me?.id ? "You" : $0.name }
        switch names.count {
        case 1: return "\(names[0]) gave kudos".uppercased()
        case 2: return "\(names[0]) and \(names[1]) gave kudos".uppercased()
        default: return "\(names[0]), \(names[1]) and \(names.count - 2) more gave kudos".uppercased()
        }
    }
}

// MARK: - Composer

/// Share a win, a photo, or a thought with your crew.
struct PostComposerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isPosting = false
    @State private var errorText: String?

    private var canPost: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil) && !isPosting
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ProfileAvatar(
                                name: store.community.me?.name ?? "",
                                avatarId: store.community.me?.avatarId,
                                size: 40
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.community.me?.name ?? "You")
                                    .font(.flexBodyBold())
                                    .foregroundStyle(Theme.ink)
                                Text("VISIBLE TO YOUR CREW")
                                    .font(.flexMono(9))
                                    .tracking(1)
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                        }

                        TextField("Share a win, a photo, a thought…", text: $text, axis: .vertical)
                            .font(.flexBody())
                            .lineLimit(4...14)
                            .padding(14)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if let image {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Button {
                                    self.image = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Theme.ink)
                                        .padding(9)
                                        .background(.thinMaterial)
                                        .clipShape(Circle())
                                }
                                .padding(10)
                            }
                        }

                        HStack(spacing: 10) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCamera = true
                                } label: {
                                    Label("Camera", systemImage: "camera")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            Button {
                                showLibrary = true
                            } label: {
                                Label("Photo", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.danger)
                        }

                        Text("Keep it kind. Posts follow the FlexUp community guidelines.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)

                Button {
                    Task { await post() }
                } label: {
                    HStack(spacing: 8) {
                        if isPosting { ProgressView().controlSize(.small).tint(Theme.background) }
                        Text(isPosting ? "Posting…" : "Post")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canPost)
                .opacity(canPost ? 1 : 0.4)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(Theme.background)
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in image = picked }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { picked in image = picked }
        }
    }

    @MainActor
    private func post() async {
        isPosting = true
        errorText = nil
        defer { isPosting = false }
        do {
            try await store.community.createPost(text: text.trimmingCharacters(in: .whitespacesAndNewlines), image: image)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Post + comments

struct PostDetailView: View {
    @Environment(AppStore.self) private var store
    let postID: String

    @State private var post: Post?
    @State private var comments: [PostComment] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorText: String?
    @State private var reportingComment: PostComment?
    @State private var reported = false

    init(post: Post) {
        postID = post.id
        _post = State(initialValue: post)
    }

    init(postID: String) {
        self.postID = postID
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let post {
                        PostCard(post: post, showsCommentLink: false) {
                            Task { self.post = await store.community.toggleKudos(post) }
                        }
                    } else if errorText == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.danger)
                    }

                    if post != nil {
                        SectionHeader(title: "Comments", subtitle: comments.isEmpty ? "Be the first to say something." : nil)
                        ForEach(comments) { comment in
                            commentRow(comment)
                        }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            if post != nil {
                inputBar
            }
        }
        .background(Theme.background)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .confirmationDialog(
            "Why are you reporting this?",
            isPresented: Binding(get: { reportingComment != nil }, set: { if !$0 { reportingComment = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    if let comment = reportingComment {
                        Task {
                            try? await store.community.report(type: "comment", id: comment.id, reason: reason)
                            reported = true
                        }
                    }
                    reportingComment = nil
                }
            }
            Button("Cancel", role: .cancel) { reportingComment = nil }
        }
        .alert("Thanks for telling us", isPresented: $reported) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We review every report within 24 hours.")
        }
    }

    private func commentRow(_ comment: PostComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: CommunityDestination.profile(comment.user.id)) {
                ProfileAvatar(user: comment.user, size: 32)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.user.id == store.community.me?.id ? "You" : comment.user.name)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
                Text(comment.text)
                    .font(.flexBody())
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            if comment.canDelete {
                Button("Delete comment", systemImage: "trash", role: .destructive) {
                    Task { await delete(comment) }
                }
            }
            if comment.user.id != store.community.me?.id {
                Button("Report comment", systemImage: "flag") { reportingComment = comment }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $draft, axis: .vertical)
                .font(.flexBody())
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    @MainActor
    private func load() async {
        do {
            if post == nil {
                post = try await store.community.post(id: postID)
            }
            if let post {
                comments = try await store.community.comments(on: post)
                self.post?.commentCount = comments.count
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func send() async {
        guard let post else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            comments = try await store.community.addComment(text, on: post)
            self.post?.commentCount = comments.count
            draft = ""
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func delete(_ comment: PostComment) async {
        guard let post else { return }
        do {
            comments = try await store.community.deleteComment(comment, on: post)
            self.post?.commentCount = comments.count
        } catch {
            errorText = error.localizedDescription
        }
    }
}
