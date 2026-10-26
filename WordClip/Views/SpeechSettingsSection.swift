import AVFoundation
import SwiftUI

struct SpeechSettingsSection: View {
    @ObservedObject private var speaker = Speaker.shared
    @State private var showClassicVoices = false

    var body: some View {
        Section {
            Picker(String(localized: "settings.speech.voice", defaultValue: "Voice"),
                   selection: $speaker.voiceIdentifier) {
                Text(String(localized: "settings.speech.system", defaultValue: "Default US English voice"))
                    .tag("")
                Section(String(localized: "settings.speech.regular", defaultValue: "Regular voices")) {
                    ForEach(speaker.regularVoices, id: \.identifier) { voice in
                        Text(verbatim: speaker.voiceName(voice)).tag(voice.identifier)
                    }
                }
                if showClassicVoices || speaker.selectedVoiceIsClassic {
                    Section(String(localized: "settings.speech.classic", defaultValue: "Classic voices")) {
                        ForEach(speaker.classicVoices, id: \.identifier) { voice in
                            Text(verbatim: speaker.voiceName(voice)).tag(voice.identifier)
                        }
                    }
                }
            }
            if !speaker.classicVoices.isEmpty {
                Toggle(String(localized: "settings.speech.showClassic", defaultValue: "Show classic voices"),
                       isOn: $showClassicVoices)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "settings.speech.rate", defaultValue: "Speaking rate"))
                    Spacer()
                    Text(verbatim: speaker.rateMultiplier.formatted(.number.precision(.fractionLength(2))) + "×")
                        .monospacedDigit()
                }
                Slider(value: $speaker.rateMultiplier, in: 0.5...1.5, step: 0.05) {
                    Text(String(localized: "settings.speech.rate", defaultValue: "Speaking rate"))
                }
                .labelsHidden()
            }
            Button {
                if speaker.isSpeaking {
                    speaker.stop()
                } else {
                    speaker.speak("Hello! Welcome to WordClip. Let's practice English together.")
                }
            } label: {
                Label(speaker.isSpeaking
                      ? String(localized: "settings.speech.stop", defaultValue: "Stop preview")
                      : String(localized: "settings.speech.preview", defaultValue: "Preview voice"),
                      systemImage: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2")
            }
            #if os(macOS)
            Link(String(localized: "settings.speech.manage", defaultValue: "Open Accessibility settings"),
                 destination: URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension")!)
            #else
            Link(String(localized: "settings.speech.guide", defaultValue: "How to add system voices"),
                 destination: URL(string: "https://support.apple.com/guide/iphone/iph96b214f0/ios")!)
            #endif
        } header: {
            Text(String(localized: "settings.section.speech", defaultValue: "Speech"))
        } footer: {
            Text(String(localized: "settings.speech.hint",
                        defaultValue: "All voices read English; regions indicate accents. Novelty voices are excluded. Classic voices use older synthesizers and may sound robotic. The original rate is 0.90×."))
            Text(String(localized: "settings.speech.downloadHint",
                        defaultValue: "To add voices, open Accessibility settings, then Read & Speak (Spoken Content on older systems). Download enhanced or premium English voices there."))
        }
        .onAppear {
            speaker.refreshVoices()
            showClassicVoices = speaker.selectedVoiceIsClassic
        }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            speaker.refreshVoices()
        }
        .onDisappear { speaker.stop() }
        .onChange(of: speaker.voiceIdentifier) { speaker.stop() }
        .onChange(of: speaker.rateMultiplier) { speaker.stop() }
        .onChange(of: showClassicVoices) {
            if !showClassicVoices, speaker.selectedVoiceIsClassic {
                speaker.voiceIdentifier = ""
            }
        }
    }
}
