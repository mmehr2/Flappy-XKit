//
//  GameScene.swift
//  Flappy XKit
//
//  Created by Michael L Mehr on 9/7/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import SpriteKit

// Z-order
enum Layer: CGFloat {
    case Background
    case Foreground
    case Player
}

class GameScene: SKScene {
    
    let worldNode = SKNode() // makes entire world movable as a unit
    var playableStart = CGFloat(0) // Y position of ground line (where foreground and background images touch)
    var playableHeight = CGFloat(0) // distance from playableStart to top of scene (this is height of background image)

    override func didMoveToView(view: SKView) {
        addChild(worldNode)
        setupBackground()
        setupForeground()
    }
    
    // MARK: Setup methods
    func setupBackground() {
        let background = SKSpriteNode(imageNamed: "Background")
        background.anchorPoint = CGPoint(x: 0.5, y: 1.0) // middle X, top Y
        background.position = CGPoint(x: size.width/2, y: size.height)
        background.zPosition = Layer.Background.rawValue
        worldNode.addChild(background) // NOTE: why does frame rate drop from 60 to 30 just by adding this node??
        
        playableHeight = background.size.height
        playableStart = size.height - playableHeight
    }
    
    func setupForeground() {
        let foreground = SKSpriteNode(imageNamed: "Ground")
        foreground.anchorPoint = CGPoint(x: 0, y: 1) // left X, top Y
        foreground.position = CGPoint(x: 0, y: playableStart)
        foreground.zPosition = Layer.Foreground.rawValue
        worldNode.addChild(foreground)
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
    }
    
    override func update(currentTime: CFTimeInterval) {
    }
}
