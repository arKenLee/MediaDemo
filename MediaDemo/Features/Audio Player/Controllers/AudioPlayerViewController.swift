//
//  AudioPlayerViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/24.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

enum AudioLoopMode {
    case random, loop, singleLoop
}

class AudioPlayerViewController: UIViewController, AVAudioPlayerDelegate {
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistsLabel: UILabel!
    @IBOutlet weak var albumImageView: UIImageView!
    
    @IBOutlet weak var lyricsView: UITextView!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var controlSlider: ControlSlider!
    
    @IBOutlet weak var loopButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!

    @IBOutlet weak var bottomButtonLayout: NSLayoutConstraint!
    
    private var timer: Timer?
    private var audioURLs = [URL]()
    
    private var trackHistory = [Int]()
    private var currentTrackIndex = -1
    private var currentLoopMode = AudioLoopMode.random
    private var sliderDragging = false
    private var shouldResumePlay = false

    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        controlSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot"), for: .normal)
        controlSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot_big"), for: .highlighted)
        
        addBlurEffectBackground()
        
        loadResources()
        
        registerNotification()
    }
    
    deinit {
        deregisterNotification()
    }
    
    
    // MARK: - Status Bar
    
    override var prefersStatusBarHidden: Bool {
        if let tabBar = self.tabBarController?.tabBar {
            return tabBar.alpha < 1e-6
        } else {
            return false
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
    // MARK: - Setup
    
    private func addBlurEffectBackground() {
        let effect = UIBlurEffect(style: .dark)
        let effectView = UIVisualEffectView(effect: effect)
        
        effectView.frame = self.view.bounds
        backgroundImageView.addSubview(effectView)

        backgroundImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedBackground(_:)))
        effectView.addGestureRecognizer(tapGesture)
    }
    
    private func loadResources() {
        let audioNames = ["TheFatRat - Unity",
                          "Colbie Caillat - Try",
                          "Chris Medina - What Are Words",
                          "OneRepublic - Counting Stars",
                          "Zella Day - East of Eden",
                          "Young Rising Sons - Turnin'"]
        
        audioURLs = audioNames.map({ (audioName: String) -> URL? in
            return Bundle.main.url(forResource: audioName, withExtension: "mp3")
        }).flatMap{$0}
        
        loadAudio(index: 0)
    }
    
    // MARK: - Audio
    private func loadAudio(index: Int) {
        guard index >= 0 && index < audioURLs.count else {
            return
        }
        
        pausePlay()
        
        currentTrackIndex = index
        trackHistory.append(index)
        let audioURL = audioURLs[index]
        let asset = AVAsset(url: audioURL)
        
        if let lyrics = asset.lyrics {
            lyricsView.text = lyrics
        } else {
            lyricsView.text = "暂时没有歌词"
        }
        
        // 标题
        let titleItems = AVMetadataItem
            .metadataItems(from: asset.commonMetadata,
                           withKey: AVMetadataCommonKeyTitle,
                           keySpace: AVMetadataKeySpaceCommon)
        
        // 艺术家
        let artistsItems = AVMetadataItem
            .metadataItems(from: asset.commonMetadata,
                           withKey: AVMetadataCommonKeyArtist,
                           keySpace: AVMetadataKeySpaceCommon)
        
        // 专辑封面
        let artworkItems = AVMetadataItem
            .metadataItems(from: asset.commonMetadata,
                           withKey: AVMetadataCommonKeyArtwork,
                           keySpace: AVMetadataKeySpaceCommon)
        
        if let titleItem = titleItems.first {
            titleLabel.text = titleItem.value as? String
        }
        
        if let artistsItem = artistsItems.first {
            artistsLabel.text = artistsItem.value as? String
        }
        
        if let artworkItem = artworkItems.first {
            if let data = artworkItem.value as? Data {
                let image = UIImage(data: data)
                backgroundImageView.image = image
                albumImageView.image = image
            } else {
                let loadImageFailureMessage = "无法获取图片: \(artworkItem.value?.description ?? "")"
                NotificationMessageWindow.show(message: loadImageFailureMessage)
            }
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                NotificationMessageWindow.show(message: "音频播放时设置音频会话类别为[播放]类别失败: \(error.localizedDescription)")
            }
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)

            if currentLoopMode == .singleLoop {
                player.numberOfLoops = NSIntegerMax
            }
            
            player.delegate = self
            player.prepareToPlay()
            
            currentTimeLabel.text = player.currentTime.playTimeString
            durationLabel.text = player.duration.playTimeString
            controlSlider.value = 0
            controlSlider.minimumValue = 0
            controlSlider.maximumValue = Float(player.duration)
            globalPlayer.audioPlayer = player
            globalPlayer.type = .audioPlayer
            
        } catch let error {
            currentTimeLabel.text = placeholderPlayTimeString
            durationLabel.text = placeholderPlayTimeString
            controlSlider.value = 0
            controlSlider.minimumValue = 0
            controlSlider.maximumValue = 1
            NotificationMessageWindow.show(message: "初始化录音播放失败: \(error.localizedDescription)")
        }
    }
    
    private func startPlay() {
        if globalPlayer.type != .audioPlayer {
            loadAudio(index: currentTrackIndex)
            startPlay()
        } else {
            
            if let player = globalPlayer.audioPlayer {
                if player.play() {
                    playPauseButton.setImage(#imageLiteral(resourceName: "audio_button_pause"), for: .normal)
                    
                    if let timer = timer, timer.isValid {
                        timer.fireDate = Date.distantPast
                    } else {
                        timer = Timer(timeInterval: 0.1, target: self, selector: #selector(updatePlayProgress), userInfo: nil, repeats: true)
                        RunLoop.current.add(timer!, forMode: .commonModes)
                    }
                }
            }
        }
    }
    
    private func pausePlay() {
        guard GlobalPlayer.shared.type == .audioPlayer else {
            return
        }
        
        if globalPlayer.audioPlayerIsPlaying {
            globalPlayer.audioPlayer?.pause()
        }
        
        playPauseButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
        
        if let timer = timer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
    }
    
    private func playAudio(playNext: Bool) {
        var index = currentTrackIndex
        
        if !playNext && trackHistory.count > 1 {
            trackHistory.removeLast()
            index = trackHistory.removeLast()
        } else {
            if !playNext {
                trackHistory.removeLast()
            }
            switch currentLoopMode {
            case .loop, .singleLoop:
                index += playNext ? 1 : -1
                if index < 0 {
                    index = audioURLs.count - 1
                } else if index == audioURLs.count {
                    index = 0
                }
            default:
                repeat {
                    index = Int(arc4random_uniform(UInt32(audioURLs.count)))
                } while index == currentTrackIndex
            }
        }
        
        loadAudio(index: index)
        startPlay()
    }
    
    @objc private func updatePlayProgress() {
        let globalPlayer = GlobalPlayer.shared
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .audioPlayer {
            
            currentTimeLabel.text = player.currentTime.playTimeString
            
            if !sliderDragging {
                controlSlider.value = Float(player.currentTime)
            }
        }
    }
    
    
    // MARK: - Actions
    
    @IBAction func playPauseButtonClicked(_ sender: UIButton) {
        if globalPlayer.type == .audioPlayer && globalPlayer.audioPlayerIsPlaying {
            pausePlay()
        } else {
            startPlay()
        }
    }
    
    @IBAction func previousButtonClicked(_ sender: UIButton) {
        playAudio(playNext: false)
    }
    
    @IBAction func nextButtonClicked(_ sender: UIButton) {
        playAudio(playNext: true)
    }
    
    @IBAction func toggleLoopMode(_ sender: UIButton) {
        guard GlobalPlayer.shared.type == .audioPlayer else {
            return
        }
        
        switch currentLoopMode {
        case .random:
            currentLoopMode = .loop
            loopButton.setImage(#imageLiteral(resourceName: "audio_button_loop_all"), for: .normal)
            globalPlayer.audioPlayer?.numberOfLoops = 0
            
        case .loop:
            currentLoopMode = .singleLoop
            loopButton.setImage(#imageLiteral(resourceName: "audio_button_loop_single"), for: .normal)
            globalPlayer.audioPlayer?.numberOfLoops = NSIntegerMax
            
        case .singleLoop:
            currentLoopMode = .random
            loopButton.setImage(#imageLiteral(resourceName: "audio_button_shuffle"), for: .normal)
            globalPlayer.audioPlayer?.numberOfLoops = 0
        }
    }
    
    @IBAction func sliderTouchDown(_ sender: UISlider) {
        sliderDragging = true
    }
    
    
    @IBAction func sliderTouchCancel(_ sender: UISlider) {
        sliderDragging = false
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .audioPlayer {
            sender.value = Float(player.currentTime)
        }
    }
    
    @IBAction func sliderTouchUp(_ sender: UISlider) {
        sliderDragging = false
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .audioPlayer && player.duration > 0 {
            player.currentTime = TimeInterval(sender.value)
            currentTimeLabel.text = player.currentTime.playTimeString
        }
    }
    
    @objc private func tappedBackground(_ sender: UITapGestureRecognizer) {
        guard let tabBar = self.tabBarController?.tabBar else { return }
        
        let duration = 0.5
        let tabBarOffset: CGFloat = 40.0
        let bottomButtonOffset: CGFloat = 30.0
        
        backgroundImageView.isUserInteractionEnabled = false
        
        if tabBar.alpha < 1e-6 {
            // 显示 Tab Bar
            UIView.animate(withDuration: duration, animations: { [unowned self] in
                tabBar.alpha = 1
                tabBar.frame.origin.y -= tabBarOffset
                self.bottomButtonLayout.constant += bottomButtonOffset
                self.view.layoutIfNeeded()
                self.setNeedsStatusBarAppearanceUpdate()
                }, completion: { [unowned self] (_) in
                    self.backgroundImageView.isUserInteractionEnabled = true
            })
        } else {
            // 隐藏 Tab Bar
            UIView.animate(withDuration: duration, animations: { [unowned self] in
                tabBar.alpha = 0
                tabBar.frame.origin.y += tabBarOffset
                self.bottomButtonLayout.constant -= bottomButtonOffset
                self.view.layoutIfNeeded()
                self.setNeedsStatusBarAppearanceUpdate()
                }, completion: { [unowned self] (_) in
                    self.backgroundImageView.isUserInteractionEnabled = true
            })
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NotificationMessageWindow.show(message: "\(player.url?.lastPathComponent ?? "") 播放完毕 \(flag)")
        
        switch currentLoopMode {
        case .singleLoop:
            loadAudio(index: currentTrackIndex)
            startPlay()
        default:
            playAudio(playNext: true)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        NotificationMessageWindow.show(message: "音频解码失败, player: \(player), error: \(error?.localizedDescription ?? "未知错误")")
    }
    
    // MARK: - Notification
    
    private func registerNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(globalPlayerTypeWillChange(_:)), name: GlobalPlayerTypeWillChange, object: globalPlayer)
        notificationCenter.addObserver(self, selector: #selector(handleInterruption(_:)), name: .AVAudioSessionInterruption, object: audioSession)
        notificationCenter.addObserver(self, selector: #selector(handleRouteChange(_:)), name: .AVAudioSessionRouteChange, object: audioSession)
        notificationCenter.addObserver(self, selector: #selector(pauseAudio(_:)), name: AllPauseNotification, object: nil)
    }
    
    private func deregisterNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.removeObserver(self, name: GlobalPlayerTypeWillChange, object: globalPlayer)
        notificationCenter.removeObserver(self, name: .AVAudioSessionInterruption, object: audioSession)
        notificationCenter.removeObserver(self, name: .AVAudioSessionRouteChange, object: audioSession)
        notificationCenter.removeObserver(self, name: AllPauseNotification, object: nil)
    }
    
    @objc private func globalPlayerTypeWillChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let oldType = userInfo[GlobalPlayerOldTypeItem] as? AudioPlayerType,
            let newType = userInfo[GlobalPlayerNewTypeItem] as? AudioPlayerType else {
                return
        }
        
        if oldType == .audioPlayer, newType != .audioPlayer {
            if globalPlayer.audioPlayerIsPlaying {
                globalPlayer.audioPlayer?.pause()
            }
            
            playPauseButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
            
            if let timer = timer, timer.isValid {
                timer.fireDate = Date.distantFuture
            }
        }
    }
    
    // 处理中断情况
    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type = AVAudioSessionInterruptionType(rawValue: typeNumber.uintValue) else {
                return
        }
        
        let globalPlayerType = GlobalPlayer.shared.type
        
        switch type {
        case .began:
            
            if globalPlayerType == .audioPlayer && globalPlayer.audioPlayerIsPlaying {
                shouldResumePlay = true
            }
            
            playPauseButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
            if let timer = timer, timer.isValid {
                timer.fireDate = Date.distantFuture
            }
            
        case .ended:
            if let optionsNumber = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber
                 {
                let options = AVAudioSessionInterruptionOptions(rawValue: optionsNumber.uintValue)
                
                if options.contains(.shouldResume) && shouldResumePlay && globalPlayerType == .audioPlayer {
                    startPlay()
                }
            }
            
            shouldResumePlay = false
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
    
    @objc private func pauseAudio(_ notification: Notification) {
        pausePlay()
    }
}
