//
//  PlayerView.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

}
