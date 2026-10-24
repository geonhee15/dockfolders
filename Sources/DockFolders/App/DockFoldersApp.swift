import SwiftUI
import AppKit

struct DockFoldersApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    // Debug hook for documentation screenshots: write the window number so
                    // `screencapture -l <id>` can capture just this window.
                    if let file = ProcessInfo.processInfo.environment["DOCKFOLDERS_WINDOW_ID_FILE"] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            let id = NSApp.keyWindow?.windowNumber ?? NSApp.windows.first?.windowNumber ?? 0
                            try? String(id).write(toFile: file, atomically: true, encoding: .utf8)
                        }
                    }
                }
        }
        .defaultSize(width: 1000, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L("New Folder")) { model.addFolder() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu(L("Dock")) {
                Button(L("Apply to Dock")) { model.apply() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.progress.isRunning || model.catalogVersion == 0)
                Button(L("Rescan Applications")) { model.rescan() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button(L("Back Up Dock Now")) { model.backupNow() }
                Button(L("Reveal Folders in Finder")) { model.revealFoldersDirectory() }
                Button(L("Open Config Folder")) { model.revealConfigFolder() }
            }
            CommandGroup(replacing: .help) {
                Link(L("DockFolders on GitHub"), destination: AppInfo.repoURL)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

/// Headless screenshot of the UI, used to verify layouts without a display: `--snapshot-ui out.png [view]`.
enum UISnapshot {
    static func run(_ args: [String]) -> Int32 {
        guard let out = args.first else {
            print("Usage: --snapshot-ui <out.png> [folder|sidebar|icon|pinned|discover|backups|settings|onboarding|picker|progress]")
            return 1
        }
        let which = args.count > 1 ? args[1] : "folder"
        return MainActor.assumeIsolated {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let model = AppModel()
            model.showOnboarding = false

            var size = NSSize(width: 1000, height: 640)
            let root: AnyView
            switch which {
            case "sidebar":
                size = NSSize(width: 260, height: 560)
                root = AnyView(SidebarView())
            case "icon":
                size = NSSize(width: 780, height: 600)
                let spec = model.config.folders.first?.icon ?? IconSpec()
                root = AnyView(IconEditorSheet(spec: .constant(spec), folderName: model.config.folders.first?.name ?? "Folder", folderIndex: 0))
            case "settings":
                size = NSSize(width: 560, height: 620)
                root = AnyView(SettingsView())
            case "onboarding":
                size = NSSize(width: 640, height: 560)
                root = AnyView(OnboardingSheet())
            case "picker":
                size = NSSize(width: 540, height: 580)
                root = AnyView(AppPickerSheet(mode: .folder(model.config.folders.first?.id ?? UUID())))
            case "progress":
                // Exercise the real apply path (use DOCKFOLDERS_DOCK_DOMAIN to keep the real Dock untouched).
                size = NSSize(width: 600, height: 520)
                model.apply()
                let until = Date().addingTimeInterval(60)
                while model.progress.isRunning && Date() < until {
                    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
                }
                root = AnyView(ProgressSheet())
            case "favorites", "pinned": model.selection = .favorites; root = AnyView(ContentView())
            case "discover": model.selection = .discover; root = AnyView(ContentView())
            case "backups": model.selection = .backups; root = AnyView(ContentView())
            default: root = AnyView(ContentView())
            }

            let hosting = NSHostingView(rootView: root.environmentObject(model).frame(width: size.width, height: size.height))
            hosting.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: size.width, height: size.height),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.contentView = hosting
            window.orderFrontRegardless()
            // Give SwiftUI time to lay out and for the catalog scan to finish.
            let deadline = Date().addingTimeInterval(4)
            while Date() < deadline {
                RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
                if !model.isScanning && Date().addingTimeInterval(2.5) > deadline { break }
            }
            hosting.layoutSubtreeIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return 1 }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { return 1 }
            do { try data.write(to: URL(fileURLWithPath: out)) } catch { print(error); return 1 }
            window.orderOut(nil)
            print("✓ \(out)")
            return 0
        }
    }
}
