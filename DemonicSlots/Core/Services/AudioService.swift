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
    /// Caches resolved file URLs so the (potentially recursive) bundle
    /// search in `resolvedURL(forKey:)` only runs once per key.
    private var resolvedURLCache: [String: URL] = [:]

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

    /// Stops one specific in-flight effect, if it's still playing (e.g. a
    /// reel spin-loop cut short by an early state change).
    func stopEffect(key: String) {
        effectPlayers[key]?.stop()
        effectPlayers[key] = nil
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

    private static let supportedExtensions = ["m4a", "caf", "mp3", "wav"]

    private func resolvedURL(forKey key: String) -> URL? {
        if let cached = resolvedURLCache[key] {
            return cached
        }

        // Fast path: flat bundle-root lookup. This is where a classic
        // "yellow group" resource ends up.
        for fileExtension in Self.supportedExtensions {
            if let url = Bundle.main.url(forResource: key, withExtension: fileExtension) {
                resolvedURLCache[key] = url
                return url
            }
        }

        // Fallback: file-system-synchronized groups can preserve the
        // on-disk subfolder structure inside the bundle instead of
        // flattening it (our audio files live under
        // Resources/Games/InfernalForge/Audio/), so a flat lookup finds
        // nothing even though the file is genuinely bundled. Search the
        // bundle recursively for a matching filename as a robust fallback
        // that works regardless of how the file ended up nested.
        guard let resourceRoot = Bundle.main.resourceURL else { return nil }
        let candidateNames = Set(Self.supportedExtensions.map { "\(key).\($0)" })
        let enumerator = FileManager.default.enumerator(
            at: resourceRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            if candidateNames.contains(url.lastPathComponent) {
                resolvedURLCache[key] = url
                return url
            }
        }

        #if DEBUG
        print("AudioService: no bundled file found for key '\(key)' (looked for \(candidateNames.sorted()))")
        #endif
        return nil
    }
}
