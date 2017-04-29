//
//  AudioPlayerViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/24.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

enum AudioPlayMode {
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
    @IBOutlet weak var controlSlider: UISlider!
    
    @IBOutlet weak var loopButton: UIButton!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!

    @IBOutlet weak var bottomButtonLayout: NSLayoutConstraint!
    
    fileprivate var timer: Timer?
    fileprivate var audioPlayer: AVAudioPlayer?
    fileprivate var audioURLs = [URL]()
    
    fileprivate var trackHistory = [Int]()
    fileprivate var currentTrackIndex = -1
    fileprivate var currentPlayMode = AudioPlayMode.random
    fileprivate var sliderDragging = false
    fileprivate var shouldResumePlay = false

    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
                          "Young Rising Sons - Turnin"]
        
        let mainBundle = Bundle.main
        
        for audioName in audioNames {
            if let audioURL = mainBundle.url(forResource: audioName, withExtension: "mp3") {
                audioURLs.append(audioURL)
            }
        }
        
        loadAudio(index: 0)
    }
    
    // MARK: - Audio
    fileprivate func loadAudio(index: Int) {
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
                NotificationMessageWindow.show(message: error.localizedDescription)
            }
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            if currentPlayMode == .singleLoop {
                player.numberOfLoops = NSIntegerMax
            }
            
            player.delegate = self
            player.prepareToPlay()
            
            currentTimeLabel.text = timeString(with: player.currentTime)
            durationLabel.text = timeString(with: player.duration)
            controlSlider.value = 0
            controlSlider.minimumValue = 0
            controlSlider.maximumValue = Float(player.duration)
            audioPlayer = player
        } catch let error {
            audioPlayer = nil
            currentTimeLabel.text = "--:--"
            durationLabel.text = "--:--"
            controlSlider.value = 0
            controlSlider.minimumValue = 0
            controlSlider.maximumValue = 1
            NotificationMessageWindow.show(message: error.localizedDescription)
        }
    }
    
    fileprivate func startPlay() {
        if let player = audioPlayer {
            if player.play() {
                toggleButton.setImage(#imageLiteral(resourceName: "button_pause"), for: .normal)
            }
        }
        
        if let timer = timer, timer.isValid {
            timer.fireDate = Date.distantPast
        } else {
            timer = Timer(timeInterval: 0.1, target: self, selector: #selector(updatePlayProgress), userInfo: nil, repeats: true)
            RunLoop.current.add(timer!, forMode: .commonModes)
        }
    }
    
    fileprivate func pausePlay() {
        toggleButton.setImage(#imageLiteral(resourceName: "button_play"), for: .normal)
        
        if let player = audioPlayer {
            player.pause()
        }
        
        if let timer = timer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
    }
    
    fileprivate func playAudio(playNext: Bool) {
        var index = currentTrackIndex
        
        if !playNext && trackHistory.count > 1 {
            trackHistory.removeLast()
            index = trackHistory.removeLast()
        } else {
            if !playNext {
                trackHistory.removeLast()
            }
            switch currentPlayMode {
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
    
    @objc fileprivate func updatePlayProgress() {
        guard let player = audioPlayer else {
            return
        }
        
        currentTimeLabel.text = timeString(with: player.currentTime)
        
        if !sliderDragging {
            controlSlider.value = Float(player.currentTime)
        }
    }
    
    fileprivate func timeString(with duration: TimeInterval) -> String {
        var time = Int(duration)
        
        let second = time % 60
        time /= 60
        
        if time < 60 {
            return String(format: "%02d:%02d", time, second)
        }
        
        let minute = time % 60
        time /= 60
        
        return String(format: "%d:%02d:%02d", time, minute, second)
    }
    
    
    // MARK: - Actions
    
    @IBAction func toggleButtonClicked(_ sender: UIButton) {
        guard let player = audioPlayer else {
            return
        }
        
        if player.isPlaying {
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
    
    @IBAction func loopButtonClicked(_ sender: UIButton) {
        switch currentPlayMode {
        case .random:
            currentPlayMode = .loop
            loopButton.setImage(#imageLiteral(resourceName: "button_loop_all"), for: .normal)
            audioPlayer?.numberOfLoops = 0
            
        case .loop:
            currentPlayMode = .singleLoop
            loopButton.setImage(#imageLiteral(resourceName: "button_loop_single"), for: .normal)
            audioPlayer?.numberOfLoops = NSIntegerMax
            
        case .singleLoop:
            currentPlayMode = .random
            loopButton.setImage(#imageLiteral(resourceName: "button_shuffle"), for: .normal)
            audioPlayer?.numberOfLoops = 0
        }
    }
    
    @IBAction func sliderTouchDown(_ sender: UISlider) {
        sliderDragging = true
    }
    
    
    @IBAction func sliderTouchCancel(_ sender: UISlider) {
        sliderDragging = false
        sender.value = Float(audioPlayer?.currentTime ?? 0)
    }
    
    @IBAction func sliderTouchUp(_ sender: UISlider) {
        sliderDragging = false
        
        if let player = audioPlayer {
            player.currentTime = TimeInterval(sender.value)
            currentTimeLabel.text = timeString(with: player.currentTime)
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
        switch currentPlayMode {
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: .AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
    }
    
    private func deregisterNotification() {
        NotificationCenter.default.removeObserver(self, name: .AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
    }
    
    // 处理中断情况
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let type = userInfo[AVAudioSessionInterruptionTypeKey] as? AVAudioSessionInterruptionType {
            switch type {
            case .began:
                if let player = audioPlayer {
                    if player.isPlaying {
                        shouldResumePlay = true
                        pausePlay()
                    }
                }
                
            case .ended:
                if let options = userInfo[AVAudioSessionInterruptionOptionKey] as? AVAudioSessionInterruptionOptions {
                    if options.contains(.shouldResume), shouldResumePlay {
                        startPlay()
                    }
                }
                shouldResumePlay = false
            }
            
        }
    }
}
