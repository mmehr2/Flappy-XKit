//
//  GameViewController.swift
//  Flappy XKit
//
//  Created by Michael L Mehr on 9/7/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController, GameSceneDelegate {
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if let skView = self.view as? SKView {
            if skView.scene == nil {
                // Create the scene
                let aspectRatio = skView.bounds.size.height / skView.bounds.size.width
                let scene = GameScene(size: CGSize(width: 320, height: 320 * aspectRatio), delegate: self)
                
                skView.showsFPS = true
                skView.showsNodeCount = true
                skView.showsPhysics = true
                skView.ignoresSiblingOrder = true // must set zPosition of each sprite to control order ourselves
                
                scene.scaleMode = .AspectFill
                
                skView.presentScene(scene)
                
            }
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
}

// MARK: Game scene delegate
extension GameViewController: GameSceneDelegate {
    func screenshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false/*opaque*/, 1.0/*scale*/)
        view.drawViewHierarchyInRect(view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func shareString(string: String, url: NSURL, image: UIImage) {
        let vc = UIActivityViewController(activityItems: [string, url, image], applicationActivities: nil)
        presentViewController(vc, animated: true, completion: nil)
    }
}