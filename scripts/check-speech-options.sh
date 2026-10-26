#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

speech_check_dir="$(mktemp -d "${TMPDIR%/}/wordclip-speech-check.XXXXXX")"
trap 'rm -rf -- "$speech_check_dir"' EXIT

cat > "$speech_check_dir/Checks.swift" <<'SWIFT'
import AVFoundation
import Foundation

@main
struct SpeechOptionsChecks {
    @MainActor static func main() throws {
        let suite = "WordClip.SpeechOptionsChecks.\(UUID().uuidString)"
        let defaults = try require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let installed = AVSpeechSynthesisVoice.speechVoices()
        let speaker = Speaker(defaults: defaults)
        precondition(speaker.voices.allSatisfy {
            $0.language.hasPrefix("en-") && !$0.voiceTraits.contains(.isNoveltyVoice)
        })
        precondition(Set(speaker.voices.map(\.identifier)) == Set(installed.filter {
            $0.language.hasPrefix("en-") && !$0.voiceTraits.contains(.isNoveltyVoice)
        }.map(\.identifier)))
        precondition(speaker.regularVoices.count + speaker.classicVoices.count == speaker.voices.count)
        precondition(Set(speaker.regularVoices.map(\.identifier))
            .isDisjoint(with: Set(speaker.classicVoices.map(\.identifier))))
        precondition(speaker.classicVoices.allSatisfy { Speaker.isClassicVoice($0) })
        for voice in speaker.voices {
            speaker.voiceIdentifier = voice.identifier
            let utterance = try require(speaker.utterance(for: "Practice English."))
            precondition(utterance.voice?.identifier == voice.identifier)
            precondition(speaker.voiceName(voice).contains(voice.name))
        }
        let novelty = installed.first { $0.language.hasPrefix("en-") && $0.voiceTraits.contains(.isNoveltyVoice) }
        if let novelty {
            defaults.set(novelty.identifier, forKey: "speech.voiceIdentifier")
            let migrated = Speaker(defaults: defaults)
            precondition(migrated.voiceIdentifier.isEmpty)
            precondition(migrated.utterance(for: "Hello.")?.voice?.identifier
                == AVSpeechSynthesisVoice(language: "en-US")?.identifier)
            // A preference assigned after refresh must not bypass the filter either.
            migrated.voiceIdentifier = novelty.identifier
            precondition(migrated.utterance(for: "Hello.")?.voice?.identifier != novelty.identifier)
        }
        if let classic = speaker.classicVoices.first {
            speaker.voiceIdentifier = classic.identifier
            let reopened = Speaker(defaults: defaults)
            precondition(reopened.voiceIdentifier == classic.identifier && reopened.selectedVoiceIsClassic)
        }
        speaker.voiceIdentifier = ""
        speaker.rateMultiplier = 1.2
        let reopened = Speaker(defaults: defaults)
        precondition(reopened.voiceIdentifier.isEmpty && reopened.rateMultiplier == 1.2)
        precondition(reopened.utterance(for: " \n ") == nil)
        print("Speech options passed: \(speaker.regularVoices.count) regular, \(speaker.classicVoices.count) classic; novelty filtering, saved preference fallback, exact voice selection and rate persistence verified.")
    }

    static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw NSError(domain: "SpeechOptionsChecks", code: 1) }
        return value
    }
}
SWIFT

swiftc -swift-version 6 -parse-as-library \
    WordClip/Services/Speaker.swift "$speech_check_dir/Checks.swift" \
    -o "$speech_check_dir/check"
"$speech_check_dir/check"
