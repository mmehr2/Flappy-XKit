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
    case Obstacle
    case Foreground
    case Player
}

class GameScene: SKScene {
    
    let kGravity: CGFloat = -1500.0 // tweak for best game feel; units are points/s²; 1000 is about earth gravity
    let kImpulse: CGFloat = 400.0 // tweak for different flap velocity; units are points/s
    let kNumForegrounds = 2 // this could be calculated from scene width and ground image width
    let kGroundSpeed: CGFloat = 150.0 // units are points/s
    let kBottomObstacleMinFraction: CGFloat = 0.1 // percent of playableHeight
    let kBottomObstacleMaxFraction: CGFloat = 0.6 // percent of playableHeight
    let kObstacleGapToPlayerHeightRatio: CGFloat = 3.5 // ratio of gap between obstacles to player height
    let kFirstSpawnDelay: NSTimeInterval = 1.75 // sec
    let kEverySpawnDelay: NSTimeInterval = 1.5 // sec
    
    let worldNode = SKNode() // makes entire world movable as a unit
    var playableStart = CGFloat(0) // Y position of ground line (where foreground and background images touch)
    var playableHeight = CGFloat(0) // distance from playableStart to top of scene (this is height of background image)
    let player = SKSpriteNode(imageNamed: "Bird0")
    var lastUpdateTime: NSTimeInterval = 0
    var dt: NSTimeInterval = 0
    var playerVelocity = CGPoint.zeroPoint
    var playerGrounded = false // MLM: added to detect state of being on ground (for sound playback)
    
    let flapAction = SKAction.playSoundFileNamed("flapping.wav", waitForCompletion: false)
    let hitGroundAction = SKAction.playSoundFileNamed("hitGround.wav", waitForCompletion: false)
    let dingAction = SKAction.playSoundFileNamed("ding.wav", waitForCompletion: false)
    let whackAction = SKAction.playSoundFileNamed("whack.wav", waitForCompletion: false)
    let fallingAction = SKAction.playSoundFileNamed("falling.wav", waitForCompletion: false)
    let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
    let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)

    override func didMoveToView(view: SKView) {
        addChild(worldNode)
        setupBackground()
        setupForeground()
        setupPlayer()
        startSpawning()
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
        for i in 0..<kNumForegrounds {
            let foreground = SKSpriteNode(imageNamed: "Ground")
            foreground.anchorPoint = CGPoint(x: 0, y: 1) // left X, top Y
            // NOTE: fix bug in Ray's code here: Ray uses the scene's size.width, but for tiling more than one small image we would want to use the image's width instead; in this case, it works out the same
            foreground.position = CGPoint(x: CGFloat(i) * foreground.size.width, y: playableStart)
            foreground.zPosition = Layer.Foreground.rawValue
            foreground.name = "foreground" // common name for later enumeration by name
            worldNode.addChild(foreground)
        }
    }
    
    func setupPlayer() {
        //player.anchorPoint = CGPoint(x: 0.5, y: 0) // middle X, bottom Y; middle X and Y is the default
        player.position = CGPoint(x: size.width * 0.2, y: playableStart + playableHeight * 0.4)
        player.zPosition = Layer.Player.rawValue
        worldNode.addChild(player)
    }
    
    // MARK: Gameplay
    
    func createObstacle() -> SKSpriteNode {
        let sprite = SKSpriteNode(imageNamed: "Cactus")
        sprite.zPosition = Layer.Obstacle.rawValue
        return sprite
    }
    
    func spawnObstacle() {
        let bottomObstacle = createObstacle()
        let startX = size.width + bottomObstacle.size.width/2 // fully off screen to the right

        let bottomObstacleMidpointY = (playableStart - bottomObstacle.size.height/2)
        let bottomObstacleMin = bottomObstacleMidpointY + playableHeight * kBottomObstacleMinFraction
        let bottomObstacleMax = bottomObstacleMidpointY + playableHeight * kBottomObstacleMaxFraction
        bottomObstacle.position = CGPointMake(startX, CGFloat.random(min: bottomObstacleMin, max: bottomObstacleMax))
        worldNode.addChild(bottomObstacle)
        
        let topObstacle = createObstacle()
        topObstacle.zRotation = CGFloat(180).degreesToRadians() // flip it 180deg around
        let bottomObstacleTopY = (bottomObstacle.position.y + bottomObstacle.size.height/2)
        let playerGap = kObstacleGapToPlayerHeightRatio * player.size.height
        topObstacle.position = CGPointMake(startX, bottomObstacleTopY + playerGap + topObstacle.size.height/2)
        worldNode.addChild(topObstacle)

        // set up the obstacle's move
        let moveX = size.width + topObstacle.size.width // from offscreen right to offscreen left (includes one obj.width)
        let moveDuration = moveX / kGroundSpeed // points divided by points/s = seconds
        // create a sequence of actions to do the move
        let sequence = SKAction.sequence([
            SKAction.moveByX(-moveX, y: 0, duration: NSTimeInterval(moveDuration)),
            SKAction.removeFromParent()
        ])
        // both obstacles run the same sequence and move together across the screen, right to left
        topObstacle.runAction(sequence)
        bottomObstacle.runAction(sequence)
    }
    
    func startSpawning() {
        let firstDelay = SKAction.waitForDuration(kFirstSpawnDelay)
        let spawn = SKAction.runBlock(spawnObstacle)
        let everyDelay = SKAction.waitForDuration(kEverySpawnDelay)
        let spawnSequence = SKAction.sequence([
            spawn, everyDelay
        ])
        let foreverSpawn = SKAction.repeatActionForever(spawnSequence)
        let overallSequence = SKAction.sequence([
            firstDelay, foreverSpawn
        ])
        // scene itself should run this, since the code isn't specific to any nodes
        runAction(overallSequence)
    }
    
    func flapPlayer() {
        // Play sound
        runAction(flapAction)
        
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
        updateForeground()
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
            if !playerGrounded {
                runAction(hitGroundAction)
            }
            playerGrounded = true
        } else {
            playerGrounded = false
        }
    }
    
    func updateForeground() {
        worldNode.enumerateChildNodesWithName("foreground", usingBlock: { node, stop in
            if let foreground = node as? SKSpriteNode {
                let moveAmount = CGPoint(x: -self.kGroundSpeed * CGFloat(self.dt), y: 0)
                foreground.position += moveAmount
                
                if foreground.position.x < -foreground.size.width {
                    foreground.position += CGPoint(x: foreground.size.width * CGFloat(self.kNumForegrounds), y: 0)
                }
            }
        })
    }
    
}
