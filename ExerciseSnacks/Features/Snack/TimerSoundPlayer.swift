import AVFAudio
import Foundation
import OSLog

/// Reuses two short PCM tones so each cue starts without loading an audio asset.
@MainActor
final class TimerSoundPlayer {
    private var countdown: AVAudioPlayer?
    private var start: AVAudioPlayer?
    private let logger = Logger(subsystem: "local.ExerciseSnacks", category: "TimerAudio")

    func prepare() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: .mixWithOthers)
            if countdown == nil { countdown = try AVAudioPlayer(data: Self.tone(duration: 0.12, frequency: 880)) }
            if start == nil { start = try AVAudioPlayer(data: Self.tone(duration: 0.55, frequency: 1100)) }
            countdown?.prepareToPlay()
            start?.prepareToPlay()
        } catch {
            logger.error("Could not prepare timer sounds: \(error.localizedDescription)")
        }
    }

    func play(_ cue: TimerCue) {
        if countdown == nil || start == nil { prepare() }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let player = cue == .countdown ? countdown : start
            player?.currentTime = 0
            player?.play()
        } catch {
            logger.error("Could not play timer sound: \(error.localizedDescription)")
        }
    }

    func stop() {
        countdown?.stop()
        start?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func tone(duration: Double, frequency: Double) -> Data {
        let sampleRate = 44_100
        let count = Int(duration * Double(sampleRate))
        let byteCount = count * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + byteCount))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(UInt16(1)) // Mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(UInt32(byteCount))
        for index in 0..<count {
            // A 5 ms envelope avoids clicks at either end of the beep.
            let envelope = min(1, Double(min(index, count - 1 - index)) / (Double(sampleRate) * 0.005))
            let wave = sin(2 * .pi * frequency * Double(index) / Double(sampleRate))
            append(Int16(wave * envelope * 0.3 * Double(Int16.max)))
        }
        return data
    }
}
