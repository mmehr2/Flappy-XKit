# FlappyXKit
This clone of the famous FlappyBird game will show how XKit can be used to port iOS designs to OS X.
Author: Michael L. Mehr (mmehr2 on Github and Twitter)
Date project coding commenced: Mon, Sept 7, 2015

PLAN
====

PHASE ONE
---------
Initially, I will do the video tutorials from the Ray Wenderlich site entitled "How To Make a Game Like Flappy Bird Series".
    http://www.raywenderlich.com/100496/video-tutorial-how-to-make-a-game-like-flappy-bird-in-swift-part-1-scene-size-and-aspect-ratios
This series of 12 video turorials (labeled Part 1 through Part 12) will enable various parts of their game called "Flappy Felipe", which itself is a clone of Flappy Bird, developed by Dong Nguyen of Vietnam in 2013, and removed from the Apple App Store in 2014. "Flappy Felipe" is currently available in the App Store, as are many other clones.
The Ray W site (as I will refer to it from now on) grants a license that allows use of the code as-is, but the artwork is proprietary and will need to be replaced.

PHASE TWO
---------
Subsequently, I will port the project as mostly SpriteKit based to OS X, as discussed in the following tutorial article:
    http://www.raywenderlich.com/87873/make-game-like-candy-crush-tutorial-os-x-port
This involves coding SpriteKit replacements for UILabel, UIButton, and UIImageView, and tweaking the event model to allow generic use of SKNode events.
NOTE: The article discusses (under section "Platform-specific UI") our Phase Three approach, but dismisses it as too much work. See especially item 2 there.

PHASE THREE
-----------
Once this phase is complete, I will develop the XKit extensions to allow a more natural port of native SpriteKit apps, involving dealing with more features of the basic UIKit classes and how they work as XKit classes on OS X.
Then I will re-implement the project using these XKit features instead of SpriteKit workarounds introduced in Phase Two.

ALTERNATIVES
============
I have considered re-creating the project as if designed for Phase Two at the start of Phase One, but I've already embarked upon the journey using the exact project from the tutorials, so we will proceed as planned.

MISC PROJECT CREDITS
====================
I wish to thank the following for ideas used in the course of the project. Consider these as footnotes as well. I will refer to them within the project as FN.x where x is the number in this list.

1. The author of the Joytek blog for this article on how to remove the warning about trying to process this README file as a source: http://joytek.blogspot.tw/2011/09/xcode-4-warning-no-rule-to-process-file.html

2. The author of this StackOverflow post that brought FN.1 to my attention: http://stackoverflow.com/questions/6509600/compilation-warning-no-rule-to-process-file-for-architecture-i386

3. The author of the StackOverflow post that converted the provided Objective-C tool to Swift:  http://stackoverflow.com/questions/19040144/spritekits-skphysicsbody-with-polygon-helper-tool

