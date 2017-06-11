//
//  FileUtil.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/11.
//  Copyright © 2017年 arKen. All rights reserved.
//

import Foundation

func urlForAudioRecordFile(with name: String) -> URL? {
    return audioRecordFileDirectory()?.appendingPathComponent(name)
}

func urlForTempAudioRecordFile(with name: String) -> URL? {
    return tempAudioRecordFileDirectory()?.appendingPathComponent(name)
}

func audioRecordFileDirectory() -> URL? {
    let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return audioRecordDirectory(relativeTo: docDirectory)
}

func tempAudioRecordFileDirectory() -> URL? {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    return audioRecordDirectory(relativeTo: tempDirectory)
}

private func audioRecordDirectory(relativeTo base: URL) -> URL? {
    let destination = base.appendingPathComponent("AudioRecord")
    
    if createDirectory(destination: destination) {
        return destination
    } else {
        return nil
    }
}

func createDirectory(destination: URL) -> Bool {
    var result = false
    
    let fileManager = FileManager.default
    var isDir: ObjCBool = false
    
    if fileManager.fileExists(atPath: destination.path, isDirectory: &isDir) {
        if !isDir.boolValue {
            do {
                try fileManager.removeItem(at: destination)
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
                result = true
            } catch let error {
                NotificationMessageWindow.show(message: error.localizedDescription)
                result = false
            }
        }
    } else {
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
            result = true
        } catch let error {
            NotificationMessageWindow.show(message: error.localizedDescription)
            result = false
        }
    }
    
    return result
}


