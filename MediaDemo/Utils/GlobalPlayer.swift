//
//  GlobalPlayer.swift
//  MediaDemo
//
//  Created by Lee on 2017/5/27.
//  Copyright © 2017年 arKen. All rights reserved.
//

import Foundation
import AVFoundation


enum AudioPlayerType {
    case audioPlayer, recordPlayer, avPlayer
}


let globalPlayer = GlobalPlayer.shared

class GlobalPlayer {
    static let shared = GlobalPlayer()
    private init(){}
    
    var type: AudioPlayerType = .audioPlayer {
        willSet(newValue) {
            let oldValue = type
            if oldValue != newValue {
                let userInfo = [GlobalPlayerOldTypeItem: oldValue, GlobalPlayerNewTypeItem: newValue]
                NotificationCenter.default.post(name: GlobalPlayerTypeWillChange, object: self, userInfo: userInfo)
            }
        }
        
        didSet {
            let newType = type
            if oldValue != newType {
                let userInfo = [GlobalPlayerOldTypeItem: oldValue, GlobalPlayerNewTypeItem: newType]
                NotificationCenter.default.post(name: GlobalPlayerTypeDidChange, object: self, userInfo: userInfo)
            }
        }
    }
    
    var audioPlayerIsPlaying: Bool {
        if let player = audioPlayer {
            return player.isPlaying
        } else {
            return false
        }
    }
    
    var audioPlayer: AVAudioPlayer?
    lazy var player = AVPlayer()
}
