//
//  SlotParticleScene.swift
//  DemonicSlots
//
//  Transparent SpriteKit layer for ambient smoke, embers and win bursts,
//  hosted via `SpriteView` on top of (or under) the SwiftUI reel field.
//  Particles are drawn procedurally with `SKShapeNode` so no texture assets
//  are required - nothing here can crash on a missing asset. The scene
//  never intercepts touches; `SlotParticleLayerView` disables hit testing.
//
import SpriteKit
import SwiftUI

final class SlotParticleScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        isUserInteractionEnabled = false
    }

    func emitAmbientSmoke() {
        guard size.width > 0, size.height > 0 else { return }
        let node = SKShapeNode(circleOfRadius: CGFloat.random(in: 26...48))
        node.fillColor = UIColor(DemonicPalette.darkViolet).withAlphaComponent(0.12)
        node.strokeColor = .clear
        node.zPosition = -1
        node.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: -30)
        node.alpha = 0
        addChild(node)

        let duration = Double.random(in: 7...11)
        let fadeIn = SKAction.fadeAlpha(to: 1, duration: duration * 0.2)
        let rise = SKAction.moveBy(x: CGFloat.random(in: -30...30), y: size.height + 60, duration: duration)
        let fadeOut = SKAction.fadeOut(withDuration: duration * 0.3)
        node.run(.sequence([fadeIn, .group([rise, .sequence([.wait(forDuration: duration * 0.7), fadeOut])]), .removeFromParent()]))
    }

    func emitEmbers(intensity: WinIntensity, around point: CGPoint? = nil) {
        guard size.width > 0, size.height > 0 else { return }
        let origin = point ?? CGPoint(x: size.width / 2, y: size.height / 2)
        let count: Int
        switch intensity {
        case .small: count = 8
        case .medium: count = 18
        case .big: count = 34
        }
        for _ in 0..<count {
            let node = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            node.fillColor = UIColor(DemonicPalette.emberOrange)
            node.strokeColor = .clear
            node.glowWidth = 2
            node.position = origin
            addChild(node)

            let duration = Double.random(in: 0.6...1.1)
            let move = SKAction.moveBy(x: CGFloat.random(in: -90...90), y: CGFloat.random(in: 30...150), duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scale(to: 0.2, duration: duration)
            node.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
        }
    }

    func emitRiftBurst() {
        guard size.width > 0, size.height > 0 else { return }
        let origin = CGPoint(x: size.width / 2, y: size.height / 2)
        for ringIndex in 0..<3 {
            let node = SKShapeNode(circleOfRadius: 6)
            node.fillColor = .clear
            node.strokeColor = UIColor(DemonicPalette.glowingViolet)
            node.lineWidth = 3
            node.glowWidth = 4
            node.position = origin
            node.alpha = 0.8
            addChild(node)

            let delay = Double(ringIndex) * 0.15
            let scale = SKAction.scale(to: 20, duration: 1.0)
            let fade = SKAction.fadeOut(withDuration: 1.0)
            node.run(.sequence([.wait(forDuration: delay), .group([scale, fade]), .removeFromParent()]))
        }
    }
}

/// SwiftUI wrapper hosting the particle scene as a non-interactive overlay.
struct SlotParticleLayerView: View {
    let scene: SlotParticleScene

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
