//
//  AudioService.swift
//  DemonicSlots
//
//  Thin AVFoundation wrapper resolving stable audio keys (from
//  `SlotAudioKeys`) to bundled files. Games ship with sound *keys* from day
//  one even before real audio assets exist - a key that resolves to nothing
//  is a silent no-op, never a crash.
//
import AVFoundation

@MainActor
final class AudioService {
    private var effectPlayers: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private let isSoundEnabledProvider: () -> Bool
    private let isMusicEnabledProvider: () -> Bool

    init(
        isSoundEnabledProvider: @escaping () -> Bool,
        isMusicEnabledProvider: @escaping () -> Bool
    ) {
        self.isSoundEnabledProvider = isSoundEnabledProvider
        self.isMusicEnabledProvider = isMusicEnabledProvider
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    func playEffect(key: String) {
        guard isSoundEnabledProvider(), !key.isEmpty, let url = resolvedURL(forKey: key) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            effectPlayers[key] = player
        } catch {
            // Missing or unreadable asset: fail silently, never crash.
        }
    }

    func startBackgroundMusic(key: String) {
        guard isMusicEnabledProvider(), !key.isEmpty, let url = resolvedURL(forKey: key) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.5
            player.prepareToPlay()
            player.play()
            musicPlayer = player
        } catch {
            // Missing or unreadable asset: fail silently, never crash.
        }
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    private func resolvedURL(forKey key: String) -> URL? {
        for fileExtension in ["m4a", "caf", "mp3", "wav"] {
            if let url = Bundle.main.url(forResource: key, withExtension: fileExtension) {
                return url
            }
        }
        return nil
    }
}
