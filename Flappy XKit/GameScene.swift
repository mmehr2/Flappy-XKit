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
    
    let kGravity: CGFloat = -1500.0 // tweak for best game feel; units are points/s²; 1000 is about earth gravity
    let kImpulse: CGFloat = 400.0 // tweak for different flap velocity; units are points/s
    
    let worldNode = SKNode() // makes entire world movable as a unit
    var playableStart = CGFloat(0) // Y position of ground line (where foreground and background images touch)
    var playableHeight = CGFloat(0) // distance from playableStart to top of scene (this is height of background image)
    let player = SKSpriteNode(imageNamed: "Bird0")
    var lastUpdateTime: NSTimeInterval = 0
    var dt: NSTimeInterval = 0
    var playerVelocity = CGPoint.zeroPoint

    override func didMoveToView(view: SKView) {
        addChild(worldNode)
        setupBackground()
        setupForeground()
        setupPlayer()
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
    
    func setupPlayer() {
        //player.anchorPoint = CGPoint(x: 0.5, y: 0) // middle X, bottom Y; middle X and Y is the default
        player.position = CGPoint(x: size.width * 0.2, y: playableStart + playableHeight * 0.4)
        player.zPosition = Layer.Player.rawValue
        worldNode.addChild(player)
    }
    
    // MARK: Gameplay
    
    func flapPlayer() {
        // Apply velocity impulse
        playerVelocity = CGPoint(x: 0, y: kImpulse)
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        flapPlayer()
    }
    
    // MARK: Updates
    
    override func update(currentTime: CFTimeInterval) {
        // called every frame, default 60 fps (or less if complicated)
        if lastUpdateTime > 0 {
            dt = currentTime - lastUpdateTime
        } else {
            dt = 0
        }
        lastUpdateTime = currentTime
        
        updatePlayer()
    }
    
    func updatePlayer() {
        // "mini physics engine" calculations
        // Apply gravity
        let gravity = CGPoint(x: 0, y: kGravity) // might not be straight up/down
        let velocityStepDueToGravity = gravity * CGFloat(dt)
        playerVelocity += velocityStepDueToGravity
        
        // Apply velocity
        let positionStepDueToVelocity = playerVelocity * CGFloat(dt)
        player.position += positionStepDueToVelocity
        
        // Ground check halt (temporary solution)
        let playerBottomDistanceFromMiddle = player.size.height/2
        if player.position.y - playerBottomDistanceFromMiddle < playableStart {
            player.position.y = playableStart + playerBottomDistanceFromMiddle
        }
    }
}
