//
//  PlayerViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

private var playerViewControllerKVOContext = 0

class PlayerViewController: UIViewController {
    
    // MARK: - Properties
    
    lazy var player = AVPlayer()
    
    var playerView: PlayerView {
        return self.view as! PlayerView
    }
    
    var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    var playerItem: AVPlayerItem? = nil {
        willSet {
            if playerItem != nil {
                let notificationCenter = NotificationCenter.default
                notificationCenter.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
                notificationCenter.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
                notificationCenter.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: playerItem)
            }
        }
        
        didSet {
            /*
             If needed, configure player item here before associating it with a player
             (example: adding outputs, setting text style rules, selecting media options)
             */
            player.replaceCurrentItem(with: playerItem)
            
            if playerItem == nil {
                cleanUpPlayerPeriodicTimeObserver()
            }
            else {
                let notificationCenter = NotificationCenter.default
                notificationCenter.addObserver(self, selector: #selector(playFinished(_:)), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                notificationCenter.addObserver(self, selector: #selector(failedToPlayToEnd(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: player.currentItem)
                notificationCenter.addObserver(self, selector: #selector(playbackStalled(_:)), name: .AVPlayerItemPlaybackStalled, object: player.currentItem)
                
                setupPlayerPeriodicTimeObserver()
            }
        }
    }
    
    private var timeObserverToken: AnyObject?
    
    // Attempt to load and test these asset keys before playing
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    var currentTime: TimeInterval {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            player.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    var duration: TimeInterval {
        guard let currentItem = player.currentItem else { return 0.0 }
        
        return CMTimeGetSeconds(currentItem.duration)
    }
    
    private var isVisible = false
    
    private var shouldResumePlay = false
    private var sliderDragging = false
    private var isFullScreen   = false
    private var isUIControlHidden = false
    
    private var isUIChanging   = false
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var pictureInPictureButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var screenModeButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeSlider: ControlSlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    
    // MARK: - Actions
    
    @IBAction func closeButtonClicked(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func togglePictureInPictureMode(_ sender: UIButton) {
    }
    
    @IBAction func playPauseButtonClicked(_ sender: UIButton) {
        if player.rate != 1.0 {
            if currentTime == duration {
                currentTime = 0.0
            }
            
            player.play()
            
            sender.setImage(#imageLiteral(resourceName: "player_button_pause"), for: .normal)
        }
        else {
            player.pause()
            
            sender.setImage(#imageLiteral(resourceName: "player_button_play"), for: .normal)
        }
    }
    
    @IBAction func toggleScreenMode(_ sender: UIButton) {
        changeScreenMode()
    }
    
    @IBAction func sliderTouchDown(_ sender: UISlider) {
        sliderDragging = true
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    @IBAction func sliderCancel(_ sender: UISlider) {
        sliderDragging = false
        sender.value = Float(currentTime)
        perform(#selector(hideUserInterfaceControl), with: self, afterDelay: 3.0)
    }
    
    @IBAction func sliderTouchUp(_ sender: UISlider) {
        sliderDragging = false
        currentTime = Double(sender.value)
        currentTimeLabel.text = currentTime.playTimeString
        perform(#selector(hideUserInterfaceControl), with: self, afterDelay: 3.0)
    }
    
    @IBAction func tappedBackgroundView(_ sender: UITapGestureRecognizer) {
        guard !isUIChanging else {
            return
        }
        
        isUIControlHidden = !isUIControlHidden
        
        if isUIControlHidden {
            hideUserInterfaceControl()
        } else {
            showUserInterfaceControl()
        }
    }
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                NotificationMessageWindow.show(message: "音频播放时设置音频会话类别为[播放]类别失败: \(error.localizedDescription)")
            }
        }
        
        timeSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot"), for: .normal)
        timeSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot_big"), for: .highlighted)
        
        playerView.playerLayer.player = player
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), options: [.new, .initial], context: &playerViewControllerKVOContext)
        addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.loadedTimeRanges), options: [.new, .initial], context: &playerViewControllerKVOContext)
        
        setupPlayerPeriodicTimeObserver()
        
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(globalPlayerTypeWillChange(_:)), name: GlobalPlayerTypeWillChange, object: globalPlayer)
        notificationCenter.addObserver(self, selector: #selector(handleInterruption(_:)), name: .AVAudioSessionInterruption, object: audioSession)
        notificationCenter.addObserver(self, selector: #selector(handleRouteChange(_:)), name: .AVAudioSessionRouteChange, object: audioSession)
        notificationCenter.addObserver(self, selector: #selector(pauseAllPlay(_:)), name: AllPauseNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        player.pause()
        
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.removeObserver(self, name: GlobalPlayerTypeWillChange, object: globalPlayer)
        notificationCenter.removeObserver(self, name: .AVAudioSessionInterruption, object: audioSession)
        notificationCenter.removeObserver(self, name: .AVAudioSessionRouteChange, object: audioSession)
        notificationCenter.removeObserver(self, name: AllPauseNotification, object: nil)
        
        cleanUpPlayerPeriodicTimeObserver()
        
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), context: &playerViewControllerKVOContext)
        removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.loadedTimeRanges), context: &playerViewControllerKVOContext)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isVisible = true
        
        if player.status == .readyToPlay {
            startPlay()
        }
        
        perform(#selector(hideUserInterfaceControl), with: self, afterDelay: 3.0)
        
        print("videoRect: \(playerView.playerLayer.videoRect)")
        print("videoGravity: \(playerView.playerLayer.videoGravity)")
        print("isReadyForDisplay: \(playerView.playerLayer.isReadyForDisplay)")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    // MARK: rotate
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.allButUpsideDown]
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if size.width > size.height {
            isFullScreen = true
        } else {
            isFullScreen = false
        }
    }
    
    // MARK: - Setup
    
    private func setupPlayerPeriodicTimeObserver() {
        // Only add the time observer if one hasn't been created yet.
        guard timeObserverToken == nil else { return }
        
        let time = CMTimeMake(1, 1)
        
        // Use a weak self variable to avoid a retain cycle in the block.
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue:DispatchQueue.main) {
            [weak self] time in
            guard let sSelf = self else { return }
            if !sSelf.sliderDragging {
                let playTime = CMTimeGetSeconds(time)
                sSelf.timeSlider.value = Float(playTime)
                sSelf.currentTimeLabel.text = playTime.playTimeString
            }
        } as AnyObject?
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func showUserInterfaceControl() {
        guard !isUIChanging else {
            return
        }
        
        isUIChanging = true
        
        timeSlider.isHidden       = false
        closeButton.isHidden      = false
        progressView.isHidden     = false
        durationLabel.isHidden    = false
        playPauseButton.isHidden  = false
        screenModeButton.isHidden = false
        currentTimeLabel.isHidden = false
        
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.timeSlider.alpha       = 1.0
            self?.closeButton.alpha      = 1.0
            self?.progressView.alpha     = 1.0
            self?.durationLabel.alpha    = 1.0
            self?.playPauseButton.alpha  = 1.0
            self?.screenModeButton.alpha = 1.0
            self?.currentTimeLabel.alpha = 1.0
        }) { [weak self] (_) in
            self?.isUIChanging = false
        }
        
        perform(#selector(hideUserInterfaceControl), with: self, afterDelay: 5.0)
    }
    
    @objc private func hideUserInterfaceControl() {
        guard !isUIChanging else {
            return
        }
        
        isUIChanging = true
        
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.timeSlider.alpha       = 0.0
            self?.closeButton.alpha      = 0.0
            self?.progressView.alpha     = 0.0
            self?.durationLabel.alpha    = 0.0
            self?.playPauseButton.alpha  = 0.0
            self?.screenModeButton.alpha = 0.0
            self?.currentTimeLabel.alpha = 0.0
        }) { [weak self] (_) in
            self?.isUIChanging = false
            self?.timeSlider.isHidden       = true
            self?.closeButton.isHidden      = true
            self?.progressView.isHidden     = true
            self?.durationLabel.isHidden    = true
            self?.playPauseButton.isHidden  = true
            self?.screenModeButton.isHidden = true
            self?.currentTimeLabel.isHidden = true
        }
        
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    private func changeScreenMode() {
        guard !isUIChanging else {
            return
        }
        
        isFullScreen = !isFullScreen
        
        if isFullScreen {
            screenModeButton.setImage(#imageLiteral(resourceName: "player_button_narrow"), for: .normal)
        }
        else {
            screenModeButton.setImage(#imageLiteral(resourceName: "player_button_fullscreen"), for: .normal)
        }
        
        rotateUserInterface()
    }
    
    private func rotateUserInterface() {
        guard !isUIChanging else {
            return
        }
    }
    
    private func pausePlay() {
        player.pause()
        playPauseButton.setImage(#imageLiteral(resourceName: "player_button_play"), for: .normal)
    }
    
    private func startPlay() {
        NotificationCenter.default.post(name: AllPauseNotification, object: self)
        player.play()
    }
    
    // MARK: - KVO
    
    // Update our UI when `player` or `player.currentItem` changes
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Only respond to KVO changes that are specific to this view controller class.
        guard context == &playerViewControllerKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(PlayerViewController.player.currentItem.duration) {
            // Update `timeSlider` and enable/disable controls when `duration` > 0.0
            
            /*
             Handle `NSNull` value for `NSKeyValueChangeNewKey`, i.e. when
             `player.currentItem` is nil.
             */
            let newDuration: CMTime
            if let newDurationAsValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
                newDuration = newDurationAsValue.timeValue
            }
            else {
                newDuration = kCMTimeZero
            }
            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            
            timeSlider.maximumValue = Float(newDurationSeconds)
            durationLabel.text = newDurationSeconds.playTimeString
            
            let currentTime = hasValidDuration ? CMTimeGetSeconds(player.currentTime()) : 0.0
            timeSlider.value = Float(currentTime)
            currentTimeLabel.text = currentTime.playTimeString
            
            playPauseButton.isEnabled = hasValidDuration
            timeSlider.isEnabled = hasValidDuration
        }
        else if keyPath == #keyPath(PlayerViewController.player.rate) {
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
            
            if newRate == 0.0 {
                playPauseButton.setImage(#imageLiteral(resourceName: "player_button_play"), for: .normal)
            } else {
                loadingIndicator.stopAnimating()
                playPauseButton.setImage(#imageLiteral(resourceName: "player_button_pause"), for: .normal)
            }
            
        }
        else if keyPath == #keyPath(PlayerViewController.player.currentItem.status) {
            // Display an error if status becomes Failed
            
            /*
             Handle `NSNull` value for `NSKeyValueChangeNewKey`, i.e. when
             `player.currentItem` is nil.
             */
            let newStatus: AVPlayerItemStatus
            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.intValue)!
            }
            else {
                newStatus = .unknown
            }
            
            if newStatus == .failed {
                if let error = player.currentItem?.error {
                    print("Load asset failed: \(error)")
                }
                let msg = "Load asset failed: " + (player.currentItem?.error?.localizedDescription ?? "Unknown error")
                NotificationMessageWindow.show(message: msg)
                
                timeSlider.value = 0;
                timeSlider.isEnabled = false
                playPauseButton.isEnabled = false
            }
            else if newStatus == .readyToPlay {
                
                if let asset = player.currentItem?.asset {
                    
                    /*
                     First test whether the values of `assetKeysRequiredToPlay` we need
                     have been successfully loaded.
                     */
                    for key in PlayerViewController.assetKeysRequiredToPlay {
                        var error: NSError?
                        if asset.statusOfValue(forKey: key, error: &error) == .failed {
                            if error != nil {
                                NotificationMessageWindow.show(message: error!.localizedDescription)
                            }
                            return
                        }
                    }
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        // We can't play this asset.
                        NotificationMessageWindow.show(message: "play failed")
                        return
                    }
                    
                    if isVisible {
                        startPlay()
                    }
                }
            }
        }
        else if keyPath == #keyPath(PlayerViewController.player.currentItem.loadedTimeRanges) {
            
            if let loadedTimeRanges = change?[NSKeyValueChangeKey.newKey] as? [NSValue], loadedTimeRanges.count > 0 {
                
                loadingIndicator.stopAnimating()
                print("loaded buffer: \(loadedTimeRanges)")
                
                let duration = player.currentItem!.duration
                let hasValidDuration = duration.isNumeric && duration.value != 0
                print("loaded duration: \(duration)")
                
                if hasValidDuration {
                    
                    let loadedTimeRange = loadedTimeRanges.first!.timeRangeValue
                    let secondsForLoaded = CMTimeGetSeconds(loadedTimeRange.start) + CMTimeGetSeconds(loadedTimeRange.duration)
                    
                    progressView.progress = Float(secondsForLoaded) / Float(CMTimeGetSeconds(duration))
                    print("progress: \(progressView.progress)")
                }
            }
        }
    }
    
    // Trigger KVO for anyone observing our properties affected by player and player.currentItem
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        let affectedKeyPathsMappingByKey: [String: Set<String>] = [
            "duration":     [#keyPath(PlayerViewController.player.currentItem.duration)],
            "rate":         [#keyPath(PlayerViewController.player.rate)]
        ]
        
        return affectedKeyPathsMappingByKey[key] ?? super.keyPathsForValuesAffectingValue(forKey: key)
    }
 
    // MARK: - Notification
    
    @objc private func playFinished(_ notification: Notification) {
        let msg = "Play finished."
        print(msg)
        NotificationMessageWindow.show(message: msg)
    }
    
    @objc private func failedToPlayToEnd(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
        let msg = "Failed to play to end: \(error?.localizedDescription ?? "Unknown")"
        print(msg)
        NotificationMessageWindow.show(message: msg)
    }
    
    @objc private func playbackStalled(_ notification: Notification) {
        let msg = "Playback stalled"
        print(msg)
        NotificationMessageWindow.show(message: msg)
        
        loadingIndicator.startAnimating()
    }
    
    @objc private func globalPlayerTypeWillChange(_ notification: Notification) {
        if player.rate > 0.0 {
            pausePlay()
        }
    }
    
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
            
            if player.rate > 0.0 {
                shouldResumePlay = true
            }
            
            playPauseButton.setImage(#imageLiteral(resourceName: "player_button_play"), for: .normal)
            
        case .ended:
            if let optionsNumber = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber
            {
                let options = AVAudioSessionInterruptionOptions(rawValue: optionsNumber.uintValue)
                
                if options.contains(.shouldResume) && shouldResumePlay && globalPlayerType == .audioPlayer {
                    player.play()
                    playPauseButton.setImage(#imageLiteral(resourceName: "player_button_pause"), for: .normal)
                }
            }
            
            shouldResumePlay = false
        }
    }
    
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
                
                if player.rate > 0.0 {
                    pausePlay()
                }
            }
        default:
            break
        }
    }
    
    @objc private func pauseAllPlay(_ notification: Notification) {
        pausePlay()
    }
}

