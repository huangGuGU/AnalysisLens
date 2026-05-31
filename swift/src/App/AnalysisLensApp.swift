import AppKit
import SwiftUI

@main
struct AnalysisLensApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920,
                       idealWidth: 980,
                       maxWidth: .infinity,
                       minHeight: 620,
                       idealHeight: 680,
                       maxHeight: .infinity)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Tools") {
                Button("Delete Metadata Cache", action: model.clearMetadataCache)
                    .disabled(model.isRunning)
            }
        }
    }
}
