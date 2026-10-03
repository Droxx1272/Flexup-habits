import SwiftUI
import LocalAuthentication

/// The way into FlexUp: a vault door that unlocks and swings open onto the
/// app. With the lock on (Privacy and data), it stays shut until Face ID,
/// Touch ID or the passcode opens it; otherwise it simply opens.
struct VaultView: View {
    /// Ask for Face ID / passcode before opening.
    let requiresUnlock: Bool
    /// Called once the door is out of the way.
    var onOpened: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dialTurn: Double = 0
    @State private var boltsRetracted = false
    @State private var doorAngle: Double = 0
    @State private var opacity: Double = 1
    @State private var clicks = 0
    @State private var isOpening = false
    @State private var isAuthenticating = false
    @State private var lockMessage: String?

    // The vault keeps its own palette so it reads as metal in both modes.
    private let backdrop = Color(light: 0x1C2733, dark: 0x0C1015)
    private let rim = Color(light: 0xD8D0BE, dark: 0x3A3934)
    private let face = Color(light: 0xEFE9DC, dark: 0x262622)
    private let detail = Color(light: 0x1C2733, dark: 0xE9E5DA)

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()
                door
                    .rotation3DEffect(
                        .degrees(doorAngle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.55
                    )
                VStack(spacing: 10) {
                    Text("FLEXUP")
                        .font(.flexDisplay(34))
                        .foregroundStyle(Color(light: 0xF4F0E6, dark: 0xF1EFE8))
                    Text(statusLine)
                        .font(.flexMono(11))
                        .tracking(3)
                        .foregroundStyle(Color(light: 0xF4F0E6, dark: 0xF1EFE8).opacity(0.6))
                }
                Spacer()
                if requiresUnlock && !isOpening {
                    VStack(spacing: 10) {
                        if let lockMessage {
                            Text(lockMessage)
                                .font(.flexCaption())
                                .foregroundStyle(Color(light: 0xF4F0E6, dark: 0xF1EFE8).opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            authenticate()
                        } label: {
                            Label("Unlock", systemImage: "faceid")
                                .font(.flexBodyBold())
                                .foregroundStyle(Color(light: 0x1C2733, dark: 0x0C1015))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(light: 0xF4F0E6, dark: 0xF1EFE8))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isAuthenticating)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                }
            }
        }
        .opacity(opacity)
        .contentShape(Rectangle())
        // Without the lock, a tap skips straight in.
        .onTapGesture { if !requiresUnlock { open() } }
        .sensoryFeedback(.impact, trigger: clicks)
        .onAppear {
            if requiresUnlock {
                authenticate()
            } else {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    open()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(requiresUnlock ? "FlexUp is locked" : "Opening FlexUp")
    }

    private var statusLine: String {
        if isOpening { return "OPENING" }
        return requiresUnlock ? "LOCKED" : "UNLOCKING"
    }

    // MARK: Door

    private var door: some View {
        ZStack {
            // Locking bolts: they stick out past the rim until the dial
            // turns, then slide back into the door.
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(detail.opacity(0.85))
                    .frame(width: 10, height: 26)
                    .offset(y: boltsRetracted ? -118 : -142)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            Circle()
                .fill(rim)
                .frame(width: 270, height: 270)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)

            Circle()
                .fill(face)
                .frame(width: 236, height: 236)
                .overlay(Circle().stroke(detail.opacity(0.12), lineWidth: 2))

            // Combination dial.
            ZStack {
                ForEach(0..<48, id: \.self) { index in
                    Rectangle()
                        .fill(detail.opacity(index % 4 == 0 ? 0.7 : 0.3))
                        .frame(width: 2, height: index % 4 == 0 ? 12 : 6)
                        .offset(y: -96)
                        .rotationEffect(.degrees(Double(index) * 7.5))
                }
            }
            .rotationEffect(.degrees(dialTurn))

            // Handle: three spokes around the hub.
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(detail)
                        .frame(width: 11, height: 140)
                        .rotationEffect(.degrees(Double(index) * 60))
                }
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(detail)
                        .frame(width: 20, height: 20)
                        .offset(y: -70)
                        .rotationEffect(.degrees(Double(index) * 60))
                }
                Circle()
                    .fill(detail)
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.accent)
            }
            .rotationEffect(.degrees(dialTurn * 0.6))
        }
        .frame(width: 300, height: 300)
        .accessibilityHidden(true)
    }

    // MARK: Opening

    private func open() {
        guard !isOpening else { return }
        withAnimation(.easeOut(duration: 0.2)) { isOpening = true }

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                onOpened()
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.75)) { dialTurn = 300 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            clicks += 1
            withAnimation(.spring(duration: 0.25)) { boltsRetracted = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            clicks += 1
            withAnimation(.easeIn(duration: 0.55)) { doorAngle = -105 }
            withAnimation(.easeIn(duration: 0.45).delay(0.2)) { opacity = 0 }
            try? await Task.sleep(nanoseconds: 700_000_000)
            onOpened()
        }
    }

    // MARK: Unlock

    /// Face ID / Touch ID with the passcode as fallback. A phone with no
    /// passcode can't lock anything, so the door just opens.
    private func authenticate() {
        guard !isAuthenticating, !isOpening else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            open()
            return
        }
        isAuthenticating = true
        lockMessage = nil
        Task { @MainActor in
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock FlexUp")
                isAuthenticating = false
                if success { open() }
            } catch {
                isAuthenticating = false
                lockMessage = "Still locked. Tap Unlock to try again."
            }
        }
    }
}

/// What the lock toggle should call itself on this phone.
enum DeviceLock {
    static var label: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "passcode"
        }
    }

    /// False when the phone has no passcode set, so there's nothing to lock with.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}
