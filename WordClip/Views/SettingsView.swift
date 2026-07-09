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
                    String(localized: "settings.capture.enabled", defaultValue: "启用选中收词"),
                    isOn: $appState.captureEnabled
                )

                LabeledContent(String(localized: "settings.capture.shortcut", defaultValue: "收词快捷键")) {
                    ShortcutRecorderField(shortcut: $collectShortcut)
                }
                .onChange(of: collectShortcut) { _, newValue in
                    KeyboardShortcuts.setShortcut(newValue, for: .collectWord)
                    appState.refreshHotkeyRegistration()
                }
            } header: {
                Text(String(localized: "settings.section.capture.selection", defaultValue: "选中收词"))
            } footer: {
                Text(String(localized: "settings.capture.selection.hint",
                    defaultValue: "在任意 App 中选中单词，按下快捷键即可收录到 WordClip。"))
                .foregroundStyle(.secondary)
            }

            // ── OCR 收词（独立于上面的开关，始终可用）──
            Section {
                // OCR 取词快捷键（Pro）：免费用户显示锁，点击弹付费墙
                if entitlement.isPro {
                    LabeledContent(String(localized: "settings.capture.ocr.shortcut",
                                          defaultValue: "OCR 收词快捷键")) {
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
                                        defaultValue: "OCR 收词快捷键"),
                                  systemImage: "text.viewfinder")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.section.capture.ocr", defaultValue: "OCR 收词"))
            } footer: {
                Text(String(localized: "settings.capture.ocr.hint",
                    defaultValue: "框选屏幕区域识别其中的英文单词（Pro），适用于图片 / PDF / 不可选文本。不受上面「选中收词」开关影响。"))
                .foregroundStyle(.secondary)
            }
            #endif

            // ── 学习（跨平台）────────────────────────────────
            Section {
                Picker(
                    String(localized: "settings.study.roundsize", defaultValue: "每轮学习词数"),
                    selection: $roundSize
                ) {
                    ForEach(roundSizeOptions, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
            } header: {
                Text(String(localized: "settings.section.study", defaultValue: "学习"))
            } footer: {
                Text(String(localized: "settings.study.roundsize.hint",
                    defaultValue: "每一轮固定学习的单词数，兼顾到期复习词与新词，学完自动结束。词量不足时学实际数量。"))
                .foregroundStyle(.secondary)
            }

            // ── 复习提醒（跨平台）────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.reminder.enabled", defaultValue: "每日复习提醒"),
                    isOn: $appState.reviewReminderEnabled
                )
                if appState.reviewReminderEnabled {
                    DatePicker(
                        String(localized: "settings.reminder.time", defaultValue: "提醒时间"),
                        selection: $appState.reviewReminderTime,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text(String(localized: "settings.section.reminder", defaultValue: "提醒"))
            }

            // ── 词典（内置 + 导入）──────────────────────────
            DictionarySettingsSection()
                .environmentObject(appState)

            // ── 账户 ──────────────────────────────────────
            Section {
                LabeledContent(
                    String(localized: "settings.plan", defaultValue: "当前方案"),
                    value: entitlement.isPro
                        ? String(localized: "settings.plan.pro", defaultValue: "Pro（终身）")
                        : String(localized: "settings.plan.free", defaultValue: "免费版")
                )
                if !entitlement.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label(String(localized: "settings.upgrade", defaultValue: "升级 WordClip Pro"),
                              systemImage: "sparkles")
                    }
                }
            } header: {
                Text(String(localized: "settings.account", defaultValue: "账户"))
            } footer: {
                if !entitlement.isPro {
                    Text(String(localized: "settings.account.hint",
                        defaultValue: "一次性购买，终身解锁 OCR 收词、iCloud 同步与导入/导出功能。"))
                    .foregroundStyle(.secondary)
                }
            }

            // ── iCloud 同步（预留 UI，功能待开发者账号）──────────
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.icloud.toggle", defaultValue: "iCloud 同步"))
                        Text(String(localized: "settings.icloud.soon", defaultValue: "即将推出"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(true)   // 预留 UI：真实同步待 CloudKit + 付费账号
            } header: {
                Text(String(localized: "settings.section.icloud", defaultValue: "同步"))
            } footer: {
                Text(String(localized: "settings.icloud.hint",
                    defaultValue: "Pro 功能：词典与学习进度跨设备自动同步。开发中，敬请期待。"))
                .foregroundStyle(.secondary)
            }

            // ── 数据（导出/导入）──────────────────────────
            Section {
                Button {
                    exportBackup()
                } label: {
                    Label(String(localized: "settings.export", defaultValue: "导出词库"),
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
                        Label(String(localized: "settings.import", defaultValue: "导入词库"),
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
                Text(String(localized: "settings.section.data", defaultValue: "数据"))
            } footer: {
                Text(entitlement.isPro
                    ? String(localized: "settings.data.hint",
                        defaultValue: "导出为 JSON 文件备份，或在新设备导入。导入按单词智能合并，不会覆盖已有的学习进度。")
                    : String(localized: "settings.data.hint.free",
                        defaultValue: "免费版可导出备份；导入为 Pro 功能。导入按单词智能合并，不会覆盖已有的学习进度。"))
                .foregroundStyle(.secondary)
            }

            // ── 通用（仅 macOS）──────────────────────────────
            #if os(macOS)
            Section {
                Toggle(
                    String(localized: "settings.general.launchatlogin", defaultValue: "登录时自动启动"),
                    isOn: $appState.launchAtLogin
                )
            } header: {
                Text(String(localized: "settings.section.general", defaultValue: "通用"))
            }
            #endif

            // ── 帮助 ──────────────────────────────────────
            Section {
                Button {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                } label: {
                    Label(String(localized: "help.open", defaultValue: "使用帮助"),
                          systemImage: "questionmark.circle")
                }
            }

            #if DEBUG
            Section {
                Toggle(
                    String(localized: "settings.debug.pro", defaultValue: "模拟 Pro（调试）"),
                    isOn: $entitlement.isPro
                )
            } header: {
                Text("Debug")
            }
            #endif
        }
        .navigationTitle(String(localized: "tab.settings", defaultValue: "设置"))
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
                                   defaultValue: "导出失败：\(error.localizedDescription)"))
            } else {
                flashBackup(String(localized: "backup.export.ok", defaultValue: "已导出词库"))
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
                               defaultValue: "导出失败：\(error.localizedDescription)"))
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
                               defaultValue: "已导入：新增 \(r.added)，合并 \(r.merged)"))
        } catch {
            flashBackup(String(localized: "backup.import.fail",
                               defaultValue: "导入失败：\(error.localizedDescription)"))
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
