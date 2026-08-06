import SwiftUI

@main
struct FlexUpApp: App {
    @State private var store = AppStore()

    init() {
        NotificationPresenter.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
