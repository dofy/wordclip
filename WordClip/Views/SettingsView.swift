import SwiftUI
import SwiftData
import WordClipKit
import UniformTypeIdentifiers
#if os(macOS)
import KeyboardShortcuts
#endif

/// 设置页
struct SettingsView: View {
    @EnvironmentObject private var entitlement: AppEntitlement
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    #if os(macOS)
    // macOS 26+ 上 name 式 Recorder 失效，改用 binding 式录制器，
    // 在 onChange 中把快捷键写回 .collectWord 名称的存储，保证全局监听照常生效。
    @State private var collectShortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .collectWord)
    @State private var ocrShortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .collectWordOCR)
    #endif

    // 备份导出/导入
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: WordBackupDocument?
    @State private var backupMessage: String?

    // 付费墙
    @State private var showingPaywall = false

    // iCloud 同步（先预留 UI，功能待付费开发者账号）
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    // 每轮学习词数（StudySession 读同一 UserDefaults 键）
    @AppStorage("study.roundSize") private var roundSize = 20
    private let roundSizeOptions = [10, 20, 30, 50]

    private var backup: BackupService {
        BackupService(modelContext: modelContext)
    }

    var body: some View {
        Form {
            #if os(macOS)
            // ── 取词（仅 macOS）──────────────────────────────
            // ── 选中收词 ──
            Section {
                Toggle(
                    String(localized: "settings.capture.enabled", defaultValue: "Enable Selection Capture"),
                    isOn: $appState.captureEnabled
                )

                LabeledContent(String(localized: "settings.capture.shortcut", defaultValue: "Shortcut")) {
                    ShortcutRecorderField(shortcut: $collectShortcut)
                }
                .onChange(of: collectShortcut) { _, newValue in
                    KeyboardShortcuts.setShortcut(newValue, for: .collectWord)
                    appState.refreshHotkeyRegistration()
                }
            } header: {
                Text(String(localized: "settings.section.capture.selection", defaultValue: "Selection Capture"))
            } footer: {
                Text(String(localized: "settings.capture.selection.hint",
                    defaultValue: "Select a word in any app and press the shortcut to save it to WordClip."))
                .foregroundStyle(.secondary)
            }

            // ── OCR 收词（独立于上面的开关，始终可用）──
            Section {
                // OCR 取词快捷键（Pro）：免费用户显示锁，点击弹付费墙
                if entitlement.isPro {
                    LabeledContent(String(localized: "settings.capture.ocr.shortcut",
                                          defaultValue: "OCR Capture Shortcut")) {
                        ShortcutRecorderField(shortcut: $ocrShortcut)
                    }
                    .onChange(of: ocrShortcut) { _, newValue in
                        KeyboardShortcuts.setShortcut(newValue, for: .collectWordOCR)
                        appState.refreshHotkeyRegistration()
                    }
                } else {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack {
                            Label(String(localized: "settings.capture.ocr.shortcut",
                                        defaultValue: "OCR Capture Shortcut"),
                                  systemImage: "text.viewfinder")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.section.capture.ocr", defaultValue: "OCR Capture"))
            } footer: {
                Text(String(localized: "settings.capture.ocr.hint",
                    defaultValue: "Select a screen region to recognize English words in it (Pro) — works with images, PDFs, and non-selectable text. Independent of the Selection Capture switch above."))
                .foregroundStyle(.secondary)
            }
            #endif

            // ── 学习（跨平台）────────────────────────────────
            Section {
                Picker(
                    String(localized: "settings.study.roundsize", defaultValue: "Words per round"),
                    selection: $roundSize
                ) {
                    ForEach(roundSizeOptions, id: \.self) { n in
                        Text(verbatim: "\(n)").tag(n)
                    }
                }
            } header: {
                Text(String(localized: "settings.section.study", defaultValue: "Study"))
            } footer: {
                Text(String(localized: "settings.study.roundsize.hint",
                    defaultValue: "How many words each round covers — a mix of due reviews and new words, ending automatically. Uses the actual count when you have fewer."))
                .foregroundStyle(.secondary)
            }

            // ── 复习提醒（跨平台）────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.reminder.enabled", defaultValue: "Daily Review Reminder"),
                    isOn: $appState.reviewReminderEnabled
                )
                if appState.reviewReminderEnabled {
                    DatePicker(
                        String(localized: "settings.reminder.time", defaultValue: "Reminder Time"),
                        selection: $appState.reviewReminderTime,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text(String(localized: "settings.section.reminder", defaultValue: "Reminder"))
            }

            // ── 词典（内置 + 导入）──────────────────────────
            DictionarySettingsSection()
                .environmentObject(appState)

            // ── 账户 ──────────────────────────────────────
            Section {
                LabeledContent(
                    String(localized: "settings.plan", defaultValue: "Current Plan"),
                    value: entitlement.isPro
                        ? String(localized: "settings.plan.pro", defaultValue: "Pro")
                        : String(localized: "settings.plan.free", defaultValue: "Free")
                )
                if !entitlement.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label(String(localized: "settings.upgrade", defaultValue: "Upgrade to WordClip Pro"),
                              systemImage: "sparkles")
                    }
                }
            } header: {
                Text(String(localized: "settings.account", defaultValue: "Account"))
            } footer: {
                if !entitlement.isPro {
                    Text(String(localized: "settings.account.hint",
                        defaultValue: "A one-time purchase that unlocks OCR capture, iCloud sync and import/export for life."))
                    .foregroundStyle(.secondary)
                }
            }

            // ── iCloud 同步（预留 UI，功能待开发者账号）──────────
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.icloud.toggle", defaultValue: "iCloud Sync"))
                        Text(String(localized: "settings.icloud.soon", defaultValue: "Coming soon"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(true)   // 预留 UI：真实同步待 CloudKit + 付费账号
            } header: {
                Text(String(localized: "settings.section.icloud", defaultValue: "Sync"))
            } footer: {
                Text(String(localized: "settings.icloud.hint",
                    defaultValue: "Pro feature: dictionaries and study progress sync across your devices. Still in development — stay tuned."))
                .foregroundStyle(.secondary)
            }

            // ── 数据（导出/导入）──────────────────────────
            Section {
                Button {
                    exportBackup()
                } label: {
                    Label(String(localized: "settings.export", defaultValue: "Export Vocabulary"),
                          systemImage: "square.and.arrow.up")
                }
                Button {
                    if entitlement.isPro {
                        showingImporter = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    HStack {
                        Label(String(localized: "settings.import", defaultValue: "Import Vocabulary"),
                              systemImage: "square.and.arrow.down")
                        if !entitlement.isPro {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.section.data", defaultValue: "Data"))
            } footer: {
                Text(entitlement.isPro
                    ? String(localized: "settings.data.hint",
                        defaultValue: "Export a JSON backup, or import on a new device. Import merges by word and won't overwrite your learning progress.")
                    : String(localized: "settings.data.hint.free",
                        defaultValue: "Exporting a backup is free; importing is a Pro feature. Import merges by word and won’t overwrite your learning progress."))
                .foregroundStyle(.secondary)
            }

            // ── 通用（仅 macOS）──────────────────────────────
            #if os(macOS)
            Section {
                Toggle(
                    String(localized: "settings.general.launchatlogin", defaultValue: "Launch at Login"),
                    isOn: $appState.launchAtLogin
                )
                Toggle(
                    String(localized: "settings.general.hidedock",
                           defaultValue: "Hide the Dock icon when the window is closed"),
                    isOn: $appState.hidesDockWhenClosed
                )
            } header: {
                Text(String(localized: "settings.section.general", defaultValue: "General"))
            } footer: {
                Text(String(localized: "settings.general.hidedock.hint",
                    defaultValue: "WordClip keeps running either way. The menu bar icon and the capture shortcuts stay available, and the Dock icon comes back with the window."))
                .foregroundStyle(.secondary)
            }
            #endif

            // ── 帮助 ──────────────────────────────────────
            Section {
                Button {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                } label: {
                    Label(String(localized: "help.open", defaultValue: "Help"),
                          systemImage: "questionmark.circle")
                }
            }

            #if DEBUG
            Section {
                Toggle(
                    String(localized: "settings.debug.pro", defaultValue: "Simulate Pro (Debug)"),
                    isOn: $entitlement.isPro
                )
            } header: {
                Text(String(localized: "settings.section.debug", defaultValue: "Debug"))
            }
            #endif
        }
        .navigationTitle(String(localized: "tab.settings", defaultValue: "Settings"))
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                flashBackup(String(localized: "backup.export.fail",
                                   defaultValue: "Export failed: \(error.localizedDescription)"))
            } else {
                flashBackup(String(localized: "backup.export.ok", defaultValue: "Vocabulary exported"))
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(entitlement)
        }
        .overlay(alignment: .bottom) {
            if let msg = backupMessage {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4, y: 2)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: backupMessage)
    }

    // MARK: - 备份操作

    private var exportFilename: String {
        "wordclip-backup"
    }

    private func exportBackup() {
        do {
            let data = try backup.export(exportedAt: Date())
            exportDocument = WordBackupDocument(data: data)
            showingExporter = true
        } catch {
            flashBackup(String(localized: "backup.export.fail",
                               defaultValue: "Export failed: \(error.localizedDescription)"))
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        // fileImporter 返回的 URL 需要 security scope 访问
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let r = try backup.importData(data)
            flashBackup(String(localized: "backup.import.result",
                               defaultValue: "Imported: \(r.added) added, \(r.merged) merged"))
        } catch {
            flashBackup(String(localized: "backup.import.fail",
                               defaultValue: "Import failed: \(error.localizedDescription)"))
        }
    }

    private func flashBackup(_ message: String) {
        backupMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if backupMessage == message { backupMessage = nil }
        }
    }
}
