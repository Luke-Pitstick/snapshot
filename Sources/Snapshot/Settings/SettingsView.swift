import SwiftUI
import AppKit

/// Three-tab settings window rooted at the SwiftUI `Settings` scene.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            HotkeysSettingsView()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            OutputSettingsView()
                .tabItem { Label("Output", systemImage: "square.and.arrow.down") }
        }
    }
}

private let settingsWidth: CGFloat = 520

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            Picker("Default destination", selection: $prefs.defaultDestination) {
                ForEach(DefaultDestination.allCases) { destination in
                    Text(destination.displayName).tag(destination)
                }
            }

            Picker("Override modifier", selection: $prefs.overrideModifierRaw) {
                ForEach(OverrideModifier.allCases) { mod in
                    Text(mod.displayName).tag(mod)
                }
            }

            LabeledContent("Thumbnail auto-dismiss") {
                HStack {
                    Slider(value: $prefs.autoDismissSeconds, in: 0...20, step: 1)
                    Text("\(Int(prefs.autoDismissSeconds))s")
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
            }

            Section {
                Text("Holding the override modifier when you press a capture hotkey flips the destination for that capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Hotkeys

struct HotkeysSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            LabeledContent("Capture Region") {
                HotKeyRecorderView(combo: $prefs.regionHotkey)
            }
            LabeledContent("Capture Full Screen") {
                HotKeyRecorderView(combo: $prefs.fullScreenHotkey)
            }
            LabeledContent("Capture Window") {
                HotKeyRecorderView(combo: $prefs.windowHotkey)
            }

            Section {
                Text("Click a shortcut, then press the keys you want. Requires at least one modifier (⌘, ⌥, ⌃, ⇧).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: prefs.regionHotkey)     { AppCoordinator.shared?.reloadHotkeys() }
        .onChange(of: prefs.fullScreenHotkey) { AppCoordinator.shared?.reloadHotkeys() }
        .onChange(of: prefs.windowHotkey)     { AppCoordinator.shared?.reloadHotkeys() }
    }
}

// MARK: - Output

struct OutputSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var currentPath: String = ""

    var body: some View {
        Form {
            LabeledContent("Save folder") {
                HStack(spacing: 8) {
                    Text(currentPath.isEmpty ? "(Default: Pictures)" : currentPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Button("Choose…") { chooseFolder() }
                }
            }

            Section {
                Text("Used when saving from the thumbnail window's Save As… action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { currentPath = prefs.defaultSaveDirectoryURL?.path ?? "" }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            prefs.defaultSaveDirectoryURL = url
            currentPath = url.path
        }
    }
}
