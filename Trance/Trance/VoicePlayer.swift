//
//  VoicePlayer.swift
//  Trance
//

@preconcurrency import AVFoundation

/// Afspiller en opus-fil fra Voice-mappen, fx VoicePlayer("E01") eller VoicePlayer("E01.opus").
final class VoicePlayer {
    private var url: URL?
    // AVAudioPlayer stopper opus-filer efter 10 sekunder, så de afspilles med AVPlayer i stedet
    private var player: AVPlayer?

    var isPlaying: Bool { (player?.rate ?? 0) > 0 }

    /// Hvor længe filen varer. Nul, hvis den ikke kunne åbnes.
    var duration: Duration = .zero

    init(_ filename: String) {
        let name = filename.hasSuffix(".opus") ? String(filename.dropLast(5)) : filename
        url = Bundle.main.url(forResource: name, withExtension: "opus")

        // AVPlayer kender ikke længden med det samme, men det gør AVAudioPlayer
        if let url, let file = try? AVAudioPlayer(contentsOf: url) {
            duration = .seconds(file.duration)
        } else {
            print("Trance voice \(filename): could not open file")
        }
    }

    /// Afspiller filen, eller fortsætter derfra, hvor der blev sat på pause.
    func play() {
        if player == nil, let url {
            player = AVPlayer(url: url)
        }
        player?.play()
    }

    func pause() {
        player?.pause()
    }
}
