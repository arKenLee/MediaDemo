//
//  AudioRecordFileListViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/17.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

class AudioRecordFileListViewController: UITableViewController, AVAudioPlayerDelegate {
    
    private var hintLabel: UILabel!
    
    private var shouldResumePlay = false
    
    struct RecordFilename {
        
        let name: String
        let filename: String
        
        init(filename: String) {
            self.filename = filename
            self.name = (filename as NSString).deletingPathExtension
        }
    }
    
    private lazy var recordFilenames: [RecordFilename] = {
        guard let directory = audioRecordFileDirectory()?.path else { return [] }
        
        let recordFiles: [RecordFilename]
        
        do {
            recordFiles = try FileManager.default.contentsOfDirectory(atPath: directory).filter {
                ($0 as NSString).pathExtension.characters.count > 0
            } .map {
                RecordFilename(filename: $0)
            }
        } catch {
            recordFiles = []
        }
        
        return recordFiles
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hintLabel = UILabel()
        hintLabel.font = UIFont.systemFont(ofSize: 22)
        hintLabel.text = "没有找到录音文件"
        hintLabel.textColor = UIColor.gray
        hintLabel.textAlignment = .center
        hintLabel.sizeToFit()
        hintLabel.center = self.view.center
        hintLabel.center.y -= 64
        self.view.addSubview(hintLabel)
        
        if recordFilenames.count == 0 {
            hintLabel.isHidden = false
            self.editButtonItem.isEnabled = false
        } else {
            hintLabel.isHidden = true
            self.editButtonItem.isEnabled = true
        }

        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing && globalPlayer.type == .recordListPlayer && globalPlayer.audioPlayerIsPlaying {
            globalPlayer.audioPlayer?.pause()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func closeButtonClicked(_ sender: UIBarButtonItem) {
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .recordListPlayer, player.isPlaying {
            player.pause()
        }
        
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if recordFilenames.count == 0 {
            hintLabel.isHidden = false
            self.editButtonItem.isEnabled = false
        } else {
            hintLabel.isHidden = true
            self.editButtonItem.isEnabled = true
        }
        
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordFilenames.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AudioRecordFileListCellIdentifier, for: indexPath)

        cell.textLabel?.text = recordFilenames[indexPath.row].name

        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let recordFile = recordFilenames[indexPath.row]
            recordFilenames.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            guard var fileURL = audioRecordFileDirectory() else {
                tableView.deselectRow(at: indexPath, animated: false)
                return
            }
            
            let filename = recordFile.filename
            fileURL.appendPathComponent(filename)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch let error {
                    NotificationMessageWindow.show(message: "删除录音文件《\(filename)》失败：\(error.localizedDescription)")
                }
            }
        }
    }
    

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard var fileURL = audioRecordFileDirectory() else {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                NotificationMessageWindow.show(message: "播放录音时设置音频会话类别为[播放]类别失败: \(error.localizedDescription)")
                return
            }
        }
        
        let filename = recordFilenames[indexPath.row].filename
        fileURL.appendPathComponent(filename)
        
        if let player = globalPlayer.audioPlayer,
            let currentPlayURL = player.url,
            globalPlayer.type == .recordListPlayer,
            fileURL == currentPlayURL {
            
            if player.isPlaying {
                tableView.deselectRow(at: indexPath, animated: false)
                player.pause()
            } else {
                player.play()
            }
            
        } else {
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer.delegate = self
                if audioPlayer.prepareToPlay() {
                    globalPlayer.audioPlayer = audioPlayer
                    globalPlayer.type = .recordListPlayer
                    if !audioPlayer.play() {
                        tableView.deselectRow(at: indexPath, animated: false)
                        NotificationMessageWindow.show(message: "播放录音文件《\(filename)》失败")
                    }
                } else {
                    tableView.deselectRow(at: indexPath, animated: false)
                    NotificationMessageWindow.show(message: "准备播放录音文件《\(filename)》失败")
                }
            } catch let error {
                tableView.deselectRow(at: indexPath, animated: false)
                NotificationMessageWindow.show(message: "播放录音文件《\(filename)》出错: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        if let url = player.url {
            NotificationMessageWindow.show(message: "播放录音文件《\(url.lastPathComponent)》出错: \(error?.localizedDescription ?? "")")
        } else {
            NotificationMessageWindow.show(message: "播放录音文件出错: \(error?.localizedDescription ?? "")")
        }
    }

    // MARK: - Notification
    
    private func registerNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(handleInterruption(_:)), name: .AVAudioSessionInterruption, object: audioSession)
        notificationCenter.addObserver(self, selector: #selector(handleRouteChange(_:)), name: .AVAudioSessionRouteChange, object: audioSession)
        notificationCenter.addObserver(self, selector: #selector(pauseAudio(_:)), name: AllPauseNotification, object: nil)
    }
    
    private func unregisterNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.removeObserver(self, name: .AVAudioSessionInterruption, object: audioSession)
        notificationCenter.removeObserver(self, name: .AVAudioSessionRouteChange, object: audioSession)
        notificationCenter.removeObserver(self, name: AllPauseNotification, object: nil)
    }
    
    
    private var lastSelectIndexPath: IndexPath?
    
    // 处理中断情况
    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type = AVAudioSessionInterruptionType(rawValue: typeNumber.uintValue) else {
                return
        }
        
        switch type {
        case .began:
            
            if globalPlayer.type == .recordListPlayer && globalPlayer.audioPlayerIsPlaying {
                shouldResumePlay = true
            }
            
            if let indexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: indexPath, animated: true)
                lastSelectIndexPath = indexPath
            }
            
        case .ended:
            if let optionsNumber = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber
            {
                let options = AVAudioSessionInterruptionOptions(rawValue: optionsNumber.uintValue)
                
                if options.contains(.shouldResume) && shouldResumePlay && globalPlayer.type == .recordListPlayer {
                    if let indexPath = lastSelectIndexPath {
                        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    }
                    globalPlayer.audioPlayer?.play()
                }
            }
            
            shouldResumePlay = false
            lastSelectIndexPath = nil
        }
        
    }
    
    // 硬件路由改变
    @objc private func handleRouteChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let routeChangeReason = userInfo[AVAudioSessionRouteChangeReasonKey] as? NSNumber,
            let reason = AVAudioSessionRouteChangeReason(rawValue: routeChangeReason.uintValue) else { return }
        
        guard let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription, previousRoute.outputs.count > 0 else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            if let portDescription = previousRoute.outputs.first,
                portDescription.portType == "Headphones" {
                
                let globalPlayerType = GlobalPlayer.shared.type
                
                if globalPlayerType == .audioPlayer && globalPlayer.audioPlayerIsPlaying {
                    pausePlay()
                }
            }
        default:
            break
        }
    }
    
    private func pausePlay() {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        globalPlayer.audioPlayer?.pause()
    }
    
    @objc private func pauseAudio(_ notification: Notification) {
        pausePlay()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
