import AVFoundation
import SwiftUI

struct SpeechSettingsSection: View {
    @ObservedObject private var speaker = Speaker.shared

    var body: some View {
        Section {
            Picker(String(localized: "settings.speech.voice", defaultValue: "Voice"),
                   selection: $speaker.voiceIdentifier) {
                Text(String(localized: "settings.speech.system", defaultValue: "System default (US English)"))
                    .tag("")
                ForEach(speaker.voices, id: \.identifier) { voice in
                    Text(verbatim: speaker.voiceName(voice)).tag(voice.identifier)
                }
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
        } header: {
            Text(String(localized: "settings.section.speech", defaultValue: "Speech"))
        } footer: {
            Text(String(localized: "settings.speech.hint",
                        defaultValue: "Uses installed English system voices for words and review cards. The original rate is 0.90×. Add more voices in your device’s Accessibility settings."))
        }
        .onAppear { speaker.refreshVoices() }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            speaker.refreshVoices()
        }
        .onDisappear { speaker.stop() }
        .onChange(of: speaker.voiceIdentifier) { speaker.stop() }
        .onChange(of: speaker.rateMultiplier) { speaker.stop() }
    }
}
