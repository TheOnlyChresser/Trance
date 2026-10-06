//
//  VoicePlayer.swift
//  Trance
//

@preconcurrency import AVFoundation

/// Afspiller en opus-fil fra Voice-mappen, fx VoicePlayer("E01") eller VoicePlayer("E01.opus").
final class VoicePlayer {
    private var player: AVAudioPlayer?

    var isPlaying: Bool { player?.isPlaying ?? false }

    init(_ filename: String) {
        let name = filename.hasSuffix(".opus") ? String(filename.dropLast(5)) : filename
        guard let url = Bundle.main.url(forResource: name, withExtension: "opus") else {
            print("Trance voice \(filename): file not found")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            print("Trance voice \(filename): \(error)")
        }
    }

    /// Afspiller filen, eller fortsætter derfra, hvor der blev sat på pause.
    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }
}
