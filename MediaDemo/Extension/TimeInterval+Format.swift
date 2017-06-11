//
//  TimeInterval+Format.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import Foundation

extension TimeInterval {
    var playTimeString: String {
        var time = Int(self)
        
        let second = time % 60
        time /= 60
        
        if time < 60 {
            return String(format: "%02d:%02d", time, second)
        }
        
        let minute = time % 60
        time /= 60
        
        return String(format: "%d:%02d:%02d", time, minute, second)
    }
    
    var recordDurationString: String {
        var time = Int(self)
        
        let second = time % 60
        time /= 60
        
        let minute = time % 60
        time /= 60
        
        if time >= 100 {
            return String(format: "%d:%02d:%02d", time, minute, second)
        } else {
            return String(format: "%02d:%02d:%02d", time, minute, second)
        }
    }
}
