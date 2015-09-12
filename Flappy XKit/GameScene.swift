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
    case UI
}

struct PhysicsCategory {
    static let None: UInt32 = 0
    static let Player: UInt32 = 1 << 0
    static let Obstacle: UInt32 = 1 << 1
    static let Ground: UInt32 = 1 << 2
}

enum GameState {
    case MainMenu
    case Tutorial
    case Play
    case Falling
    case ShowingScore
    case GameOver
}

// protocol for sharing bragging rights
protocol GameSceneDelegate {
    func screenshot() -> UIImage
    func shareString(string: String, url: NSURL, image: UIImage)
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    let kGravity: CGFloat = -1500.0 // tweak for best game feel; units are points/s²; 1000 is about earth gravity
    let kImpulse: CGFloat = 400.0 // tweak for different flap velocity; units are points/s
    let kNumForegrounds = 2 // this could be calculated from scene width and ground image width
    let kGroundSpeed: CGFloat = 150.0 // units are points/s
    let kBottomObstacleMinFraction: CGFloat = 0.1 // percent of playableHeight
    let kBottomObstacleMaxFraction: CGFloat = 0.6 // percent of playableHeight
    let kObstacleGapToPlayerHeightRatio: CGFloat = 3.5 // ratio of gap between obstacles to player height
    let kFirstSpawnDelay: NSTimeInterval = 1.75 // sec
    let kEverySpawnDelay: NSTimeInterval = 1.5 // sec
    let kFontName = "AmericanTypewriter-Bold"
    let kMargin: CGFloat = 20.0 // points; upper margin above score label
    let kFontColor = SKColor(red: 101.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1.0)
    let kAnimationDelay = 0.3 // sec
    
    let worldNode = SKNode() // makes entire world movable as a unit
    var playableStart = CGFloat(0) // Y position of ground line (where foreground and background images touch)
    var playableHeight = CGFloat(0) // distance from playableStart to top of scene (this is height of background image)
    let player = SKSpriteNode(imageNamed: "Bird0")
    var lastUpdateTime: NSTimeInterval = 0
    var dt: NSTimeInterval = 0
    var playerVelocity = CGPoint.zeroPoint
    let sombrero = SKSpriteNode(imageNamed: "Sombrero")
    var hitGround = false // physics collision detected: grounded
    var hitObstacle = false // physics collision detected: obstacle
    var gameState: GameState = .Play
    var scoreLabel: SKLabelNode!
    var score = 0
    var gameSceneDelegate: GameSceneDelegate
    
    let flapAction = SKAction.playSoundFileNamed("flapping.wav", waitForCompletion: false)
    let hitGroundAction = SKAction.playSoundFileNamed("hitGround.wav", waitForCompletion: false)
    let dingAction = SKAction.playSoundFileNamed("ding.wav", waitForCompletion: false)
    let whackAction = SKAction.playSoundFileNamed("whack.wav", waitForCompletion: false)
    let fallingAction = SKAction.playSoundFileNamed("falling.wav", waitForCompletion: false)
    let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
    let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)

    init(size: CGSize, delegate: GameSceneDelegate) {
        self.gameSceneDelegate = delegate
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToView(view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        
        addChild(worldNode)
        setupBackground()
        setupForeground()
        setupPlayer()
        setupSombrero()
        startSpawning()
        setupLabel()
        
        flapPlayer() // give the user a chance!
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
        
        // physics engine support - add to scene itself since it's a world boundary
        let lowerLeft = CGPoint(x: 0, y: playableStart)
        let lowerRight = CGPoint(x: size.width, y: playableStart)
        self.physicsBody = SKPhysicsBody(edgeFromPoint: lowerLeft, toPoint: lowerRight)
        self.physicsBody?.categoryBitMask = PhysicsCategory.Ground
        self.physicsBody?.collisionBitMask = 0
        self.physicsBody?.contactTestBitMask = PhysicsCategory.Player
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

        // physics body support [**[see FN.3]**]
        let offsetX = player.size.width * player.anchorPoint.x
        let offsetY = player.size.height * player.anchorPoint.y
        
        let path = CGPathCreateMutable()
        
        CGPathMoveToPoint(path, nil, 3 - offsetX, 14 - offsetY)
        CGPathAddLineToPoint(path, nil, 23 - offsetX, 29 - offsetY)
        CGPathAddLineToPoint(path, nil, 35 - offsetX, 28 - offsetY)
        CGPathAddLineToPoint(path, nil, 39 - offsetX, 22 - offsetY)
        CGPathAddLineToPoint(path, nil, 39 - offsetX, 10 - offsetY)
        CGPathAddLineToPoint(path, nil, 33 - offsetX, 3 - offsetY)
        CGPathAddLineToPoint(path, nil, 25 - offsetX, 3 - offsetY)
        CGPathAddLineToPoint(path, nil, 23 - offsetX, 0 - offsetY)
        CGPathAddLineToPoint(path, nil, 5 - offsetX, 0 - offsetY)
        
        CGPathCloseSubpath(path)
        
        player.physicsBody = SKPhysicsBody(polygonFromPath: path)
        player.physicsBody?.categoryBitMask = PhysicsCategory.Player
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.contactTestBitMask = PhysicsCategory.Obstacle | PhysicsCategory.Ground
        
        
        worldNode.addChild(player)
    }
    
    func setupSombrero() {
        // add the sombrero positioned on the player's head, down over the eyes a bit
        // this version from RayW makes no sense to me; why choose the magic numbers?
        let magicX: CGFloat = 31.0
        let magicY: CGFloat = 29.0
        sombrero.position = CGPoint(x: magicX - sombrero.size.width/2, y: magicY - sombrero.size.height/2)
        player.addChild(sombrero)
    }
    
    func setupLabel() {
        scoreLabel = SKLabelNode(fontNamed: kFontName)
        // Ray says that the magic color numbers came from his
        scoreLabel.fontColor = kFontColor
        scoreLabel.position = CGPoint(x: size.width/2, y: size.height - kMargin)
        scoreLabel.text = "\(score)"
        scoreLabel.verticalAlignmentMode = .Top
        scoreLabel.zPosition = Layer.UI.rawValue
        worldNode.addChild(scoreLabel)
    }
    
    func setupScorecard() {
        if score > bestScore() {
            setBestScore(score)
        }
        
        //let commonScoreName = "Tutorial" // for all elements, to allow single enum call for removal

        let scorecard = SKSpriteNode(imageNamed: "ScoreCard")
        scorecard.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        scorecard.name = "Tutorial"
        scorecard.zPosition = Layer.UI.rawValue
        worldNode.addChild(scorecard)
        
        let lastScore = SKLabelNode(fontNamed: kFontName)
        lastScore.fontColor = kFontColor
        lastScore.position = CGPoint(x: -scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
        lastScore.text = "\(score)"
        scorecard.addChild(lastScore)
        
        let bestScoreLabel = SKLabelNode(fontNamed: kFontName)
        bestScoreLabel.fontColor = kFontColor
        bestScoreLabel.position = CGPoint(x: scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
        bestScoreLabel.text = "\(self.bestScore())"
        scorecard.addChild(bestScoreLabel)

        let yDistance = scorecard.size.height/2 + kMargin
        let gameOver = SKSpriteNode(imageNamed: "GameOver")
        gameOver.position = CGPoint(x: size.width/2, y: size.height/2 + yDistance + gameOver.size.height/2)
        gameOver.zPosition = Layer.UI.rawValue
        worldNode.addChild(gameOver)
        
        let okButton = SKSpriteNode(imageNamed: "Button")
        okButton.position = CGPoint(x: size.width * 0.25, y: size.height/2 - yDistance - okButton.size.height/2)
        okButton.zPosition = Layer.UI.rawValue
        worldNode.addChild(okButton)
        
        let ok = SKSpriteNode(imageNamed: "OK")
        ok.position = CGPoint.zeroPoint
        ok.zPosition = Layer.UI.rawValue
        okButton.addChild(ok)
        
        let shareButton = SKSpriteNode(imageNamed: "Button")
        shareButton.position = CGPoint(x: size.width * 0.75, y: size.height/2 - yDistance - shareButton.size.height/2)
        shareButton.zPosition = Layer.UI.rawValue
        worldNode.addChild(shareButton)
        
        let share = SKSpriteNode(imageNamed: "Share")
        share.position = CGPoint.zeroPoint
        share.zPosition = Layer.UI.rawValue
        shareButton.addChild(share)
        
        // animation: gameOver scales and fades in at its final position (no motion)
        gameOver.setScale(0)
        gameOver.alpha = 0
        let group = SKAction.group([
            SKAction.fadeInWithDuration(kAnimationDelay),
            SKAction.scaleTo(1.0, duration: kAnimationDelay)
            ])
        group.timingMode = .EaseInEaseOut
        gameOver.runAction(SKAction.sequence([
            SKAction.waitForDuration(kAnimationDelay),
            group
            ]))
        
        // scorecard slides in from the bottom
        scorecard.position = CGPoint(x: size.width/2, y: -scorecard.size.height/2)
        let moveTo = SKAction.moveTo(CGPoint(x: size.width/2, y: size.height/2), duration: kAnimationDelay)
        moveTo.timingMode = .EaseInEaseOut
        scorecard.runAction(SKAction.sequence([
            SKAction.waitForDuration(kAnimationDelay * 2),
            moveTo
            ]))
        
        // OK and Share buttons fade in, also in place
        okButton.alpha = 0
        shareButton.alpha = 0
        let fadeIn = SKAction.sequence([
            SKAction.waitForDuration(kAnimationDelay * 3),
            SKAction.fadeInWithDuration(kAnimationDelay)
            ])
        fadeIn.timingMode = .EaseInEaseOut
        okButton.runAction(fadeIn)
        shareButton.runAction(fadeIn)
        
        // run a sound-track in parallel, ending in a game state change
        let pops = SKAction.sequence([
            SKAction.waitForDuration(kAnimationDelay),
            popAction,
            SKAction.waitForDuration(kAnimationDelay),
            popAction,
            SKAction.waitForDuration(kAnimationDelay),
            popAction,
            SKAction.runBlock(switchToGameOver)
            ])
        runAction(pops)
   }
    
    // MARK: Gameplay
    
    func createObstacle() -> SKSpriteNode {
        let sprite = SKSpriteNode(imageNamed: "Cactus")
        sprite.zPosition = Layer.Obstacle.rawValue
        sprite.userData = NSMutableDictionary()
        
        // physics body for obstacle [**[see FN.3]**]
        let offsetX = sprite.size.width * sprite.anchorPoint.x
        let offsetY = sprite.size.height * sprite.anchorPoint.y
        
        let path = CGPathCreateMutable()
        
        CGPathMoveToPoint(path, nil, 4 - offsetX, 314 - offsetY)
        CGPathAddLineToPoint(path, nil, 51 - offsetX, 314 - offsetY)
        CGPathAddLineToPoint(path, nil, 49 - offsetX, 1 - offsetY)
        CGPathAddLineToPoint(path, nil, 2 - offsetX, 0 - offsetY)
        
        CGPathCloseSubpath(path)
        
        sprite.physicsBody = SKPhysicsBody(polygonFromPath: path)
        sprite.physicsBody?.categoryBitMask = PhysicsCategory.Obstacle
        sprite.physicsBody?.collisionBitMask = 0
        sprite.physicsBody?.contactTestBitMask = PhysicsCategory.Player
        
        return sprite
    }
    
    func spawnObstacle() {
        let bottomObstacle = createObstacle()
        let startX = size.width + bottomObstacle.size.width/2 // fully off screen to the right

        let bottomObstacleMidpointY = (playableStart - bottomObstacle.size.height/2)
        let bottomObstacleMin = bottomObstacleMidpointY + playableHeight * kBottomObstacleMinFraction
        let bottomObstacleMax = bottomObstacleMidpointY + playableHeight * kBottomObstacleMaxFraction
        bottomObstacle.position = CGPointMake(startX, CGFloat.random(min: bottomObstacleMin, max: bottomObstacleMax))
        bottomObstacle.name = "BottomObstacle"
        worldNode.addChild(bottomObstacle)
        
        let topObstacle = createObstacle()
        topObstacle.zRotation = CGFloat(180).degreesToRadians() // flip it 180deg around
        let bottomObstacleTopY = (bottomObstacle.position.y + bottomObstacle.size.height/2)
        let playerGap = kObstacleGapToPlayerHeightRatio * player.size.height
        topObstacle.position = CGPointMake(startX, bottomObstacleTopY + playerGap + topObstacle.size.height/2)
        topObstacle.name = "TopObstacle"
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
        runAction(overallSequence, withKey: "spawn")
    }
    
    func stopSpawning() {
        removeActionForKey("spawn")
        // since Top and Bottom obstacles have different names (due to scoring), we need to do this removal for both
        ["TopObstacle", "BottomObstacle"].map {
            self.worldNode.enumerateChildNodesWithName($0, usingBlock: {node, stop in
                node.removeAllActions()
            })
        }
    }
    
    func tipSombrero() {
        // move the hat up 12 pixels over .15 sec with ease-in/ease-out timing mode
        let kHatMoveDistance = CGFloat(12.0) // points, not pixels - do we need to convert?
        let kHatMoveTime = NSTimeInterval(0.15)
        let moveUp = SKAction.moveByX(0, y: kHatMoveDistance, duration: kHatMoveTime)
        moveUp.timingMode = .EaseInEaseOut
        // then move the same distance back down over the same duration
        let moveDown = moveUp.reversedAction()
        let tipSequence = SKAction.sequence([
            moveUp,
            moveDown
            ])
        sombrero.runAction(tipSequence)
    }
    
    func flapPlayer() {
        // Play sound
        runAction(flapAction)
        
        // Tip the old sombrero
        tipSombrero()
        
        // Apply velocity impulse
        playerVelocity = CGPoint(x: 0, y: kImpulse)
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        let touch = touches.first as? UITouch
        let touchLocation = touch?.locationInNode(self)
        
        switch gameState {
        case .MainMenu:
            break
        case .Tutorial:
            break
        case .Play:
            flapPlayer()
            break
        case .Falling:
            break
        case .ShowingScore:
            break
        case .GameOver:
            // NOTE: split tap events by half-screen: left half will restart, right half (40%??) will share
            if touchLocation?.x > size.width * 0.6 {
                shareScore()
            } else {
                switchToNewGame()
            }
            break
        }
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
        
        switch gameState {
        case .MainMenu:
            break
        case .Tutorial:
            break
        case .Play:
            updatePlayer()
            updateForeground()
            checkHitObstacle()
            checkHitGround()
            updateScore()
            break
        case .Falling:
            updatePlayer()
            checkHitGround()
            break
        case .ShowingScore:
            break
        case .GameOver:
            break
        }
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
    
    func checkHitObstacle() {
        if hitObstacle {
            hitObstacle = false
            switchToFalling()
        }
    }
    
    func checkHitGround() {
        if hitGround {
            hitGround = false
            playerVelocity = CGPoint(x: 0, y: 0)
            player.zRotation = CGFloat(-90).degreesToRadians()
            player.position = CGPoint(x: player.position.x, y: playableStart + player.size.width/2)
            runAction(hitGroundAction)
            switchToShowScore()
        }
    }
    
    func updateScore() {
        let typicalObstacle = "TopObstacle" // pick one (top or bottom) arbitrarily, else we would double-score
        worldNode.enumerateChildNodesWithName(typicalObstacle, usingBlock: { node, stop in
            if let obstacle = node as? SKSpriteNode {
                 // if current obstacle has a dictionary with the key "Passed", then we're done looking at that obstacle
                if let passed = obstacle.userData?["Passed"] as? NSNumber
                    where passed.boolValue {
                        return
                }
                // else if player's position is beyond the obstacle's right edge...
                if self.player.position.x > obstacle.position.x + obstacle.size.width/2 {
                    // bump the score
                    self.addToScore()
                    self.scoreLabel.text = "\(self.score)"
                    // play a sound
                    self.runAction(self.coinAction)
                    // and set the Passed key in its dictionary
                    obstacle.userData?["Passed"] = NSNumber(bool: true)
                }
            }
        })
    }
    
    // MARK: Game states
    
    func switchToFalling() {
        gameState = .Falling
        
        // sequence the sound effects (whack, then falling)
        runAction(SKAction.sequence([whackAction,
            SKAction.waitForDuration(0.1),
            fallingAction]))
        
        player.removeAllActions()
        stopSpawning()
    }
    
    func switchToShowScore() {
        gameState = .ShowingScore
        player.removeAllActions()
        stopSpawning()
        setupScorecard()
    }
    
    func switchToNewGame() {
        if let skView = view {
            let newScene = GameScene(size: size, delegate: gameSceneDelegate)
            let transition = SKTransition.fadeWithColor(SKColor.blackColor(), duration: 0.5) //crossFadeWithDuration(1.0)
            runAction(popAction)
            skView.presentScene(newScene, transition: transition)
        }
    }
    
    func switchToGameOver() {
        gameState = .GameOver
    }
    
    // MARK: Score
    
    func bestScore() -> Int {
        return NSUserDefaults.standardUserDefaults().integerForKey("BestScore")
    }
    
    func setBestScore(bestScore: Int) {
        NSUserDefaults.standardUserDefaults().setInteger(bestScore, forKey: "BestScore")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func addToScore() {
        ++score
        if score > bestScore() {
            setBestScore(score)
        }
    }
    
    func shareScore() {
        let kAppStoreID = 0 //82406590 // NOTE: this is Ray's, we need our own app ID here!!
        let urlString = "http://itunes.apple.com/app/id\(kAppStoreID)?mt=8"
        let screenshot = gameSceneDelegate.screenshot()
        let initialTextString = "OMG! I scored \(score) points in Flappy XKit!"
        if let url = NSURL(string: urlString) {
            gameSceneDelegate.shareString(initialTextString, url: url, image: screenshot)
        } else {
            // TBD: present the error onscreen somehow
        }
    }
    
    // MARK: Physics
    
    func didBeginContact(contact: SKPhysicsContact) {
        let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
        
        if other.categoryBitMask == PhysicsCategory.Ground {
            hitGround = true
        }
        if other.categoryBitMask == PhysicsCategory.Obstacle {
            hitObstacle = true
        }
    }
    
    
}
