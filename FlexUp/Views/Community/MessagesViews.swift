import SwiftUI
import UIKit

/// Conversations with your crew. Messaging is friends-only.
struct MessagesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var loaded = false

    private var community: CommunityStore { store.community }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !community.isSignedIn {
                    CommunityGateView()
                } else if community.threads.isEmpty {
                    if loaded {
                        EmptyStateCard(
                            icon: "bubble.left.and.bubble.right",
                            title: "No one to message yet",
                            message: "Messages are for your crew. Add a friend with their code, and you can talk here."
                        )
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                } else {
                    ForEach(community.threads) { thread in
                        NavigationLink(value: CommunityDestination.chat(thread.user)) {
                            row(thread)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .refreshable { await community.loadThreads() }
        .task {
            await community.loadThreads()
            loaded = true
        }
    }

    private func row(_ thread: MessageThread) -> some View {
        HStack(spacing: 12) {
            ProfileAvatar(user: thread.user, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.user.name)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if let lastAt = thread.lastAt {
                        Text(lastAt.formatted(.relative(presentation: .named)))
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                HStack {
                    Text(preview(thread))
                        .font(thread.unread > 0 ? .flexBodyBold() : .flexCaption())
                        .foregroundStyle(thread.unread > 0 ? Theme.ink : Theme.inkSubtle)
                        .lineLimit(1)
                    Spacer()
                    if thread.unread > 0 {
                        Text("\(thread.unread)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func preview(_ thread: MessageThread) -> String {
        guard let text = thread.lastText else { return "Say hi 👋" }
        return thread.lastFromMe ? "You: \(text)" : text
    }
}

// MARK: - Chat

/// One conversation. New messages arrive by polling every few seconds while
/// the screen is open — real push arrives with APNs.
struct ChatView: View {
    @Environment(AppStore.self) private var store
    let user: CommunityUser

    @State private var messages: [DirectMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorText: String?
    @State private var reportingMessage: DirectMessage?
    @State private var reported = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if loaded && messages.isEmpty {
                            Text("This is the start of your conversation with \(user.name).")
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                                .padding(.vertical, 30)
                        }
                        ForEach(messages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, 16)
            }

            inputBar
        }
        .background(Theme.background)
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: CommunityDestination.profile(user.id)) {
                    ProfileAvatar(user: user, size: 30)
                }
            }
        }
        .task { await poll() }
        .confirmationDialog(
            "Why are you reporting this?",
            isPresented: Binding(get: { reportingMessage != nil }, set: { if !$0 { reportingMessage = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    if let message = reportingMessage {
                        Task {
                            try? await store.community.report(type: "message", id: message.id, reason: reason)
                            reported = true
                        }
                    }
                    reportingMessage = nil
                }
            }
            Button("Cancel", role: .cancel) { reportingMessage = nil }
        }
        .alert("Thanks for telling us", isPresented: $reported) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We review every report within 24 hours. You can block \(user.name) from their profile.")
        }
    }

    private func bubble(_ message: DirectMessage) -> some View {
        HStack {
            if message.fromMe { Spacer(minLength: 50) }
            Text(message.text)
                .font(.flexBody())
                .foregroundStyle(message.fromMe ? Theme.background : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.fromMe ? Theme.ink : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contextMenu {
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.text }
                    if !message.fromMe {
                        Button("Report message", systemImage: "flag") { reportingMessage = message }
                    }
                }
            if !message.fromMe { Spacer(minLength: 50) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message \(user.name)…", text: $draft, axis: .vertical)
                .font(.flexBody())
                .lineLimit(1...5)
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
    }

    @MainActor
    private func poll() async {
        do {
            messages = try await store.community.messages(with: user)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        loaded = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { break }
            await fetchNew()
        }
    }

    @MainActor
    private func fetchNew() async {
        guard let newer = try? await store.community.messages(with: user, after: messages.last?.createdAt) else { return }
        merge(newer)
    }

    @MainActor
    private func merge(_ incoming: [DirectMessage]) {
        let known = Set(messages.map(\.id))
        let fresh = incoming.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        messages.append(contentsOf: fresh)
        messages.sort { $0.createdAt < $1.createdAt }
    }

    @MainActor
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            let message = try await store.community.send(text, to: user)
            draft = ""
            errorText = nil
            merge([message])
        } catch {
            errorText = error.localizedDescription
        }
    }
}
