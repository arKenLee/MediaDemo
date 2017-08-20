//
//  AssetUtil.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/17.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

// 拼接音频
func pieceAudio(url1: URL, audio2 url2: URL, outputURL: URL, completion: ((Bool)->Void)?) {
    
    let fileManager = FileManager.default
    
    let audio1Exists = fileManager.fileExists(atPath: url1.path)
    let audio2Exists = fileManager.fileExists(atPath: url2.path)
    
    guard audio1Exists || audio2Exists else {
        completion?(false)
        return
    }
    
    let composition = AVMutableComposition()
    
    let audioAsset1 = AVURLAsset(url: url1)
    let audioAsset2 = AVURLAsset(url: url2)
    
    var timePosition = kCMTimeZero
    
    if let audioAssetTrack1 = audioAsset1.tracks(withMediaType: AVMediaTypeAudio).first {
        
        let timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset1.duration)
        let track = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: 0)
        
        do {
            try track.insertTimeRange(timeRange, of: audioAssetTrack1, at: timePosition)
            timePosition = audioAsset1.duration
        } catch let error {
            NotificationMessageWindow.show(message: "插入第一个音轨失败: \(error.localizedDescription)")
        }
    }
    
    if let audioAssetTrack2 = audioAsset2.tracks(withMediaType: AVMediaTypeAudio).first {
        
        let timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset2.duration)
        let track = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: 0)
        
        do {
            try track.insertTimeRange(timeRange, of: audioAssetTrack2, at: timePosition)
            timePosition = audioAsset2.duration
        } catch let error {
            NotificationMessageWindow.show(message: "插入第二个音轨失败: \(error.localizedDescription)")
        }
    }
    
    guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
        completion?(false)
        return
    }
    
    session.outputURL = outputURL
    session.outputFileType = AVFileTypeAppleM4A
    
    session.exportAsynchronously {
        let success = (session.status == .completed)
        completion?(success)
    }
}


func thumbnailImage(from url: URL, time: CMTime) -> UIImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    
    do {
        let thumbnailImageRef = try generator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: thumbnailImageRef)
    } catch let error as NSError {
        print("error: \(error.localizedDescription)")
        return nil
    }
}

