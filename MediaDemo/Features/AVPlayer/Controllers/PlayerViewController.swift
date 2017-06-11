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

class PlayerViewController: UIViewController, AVPictureInPictureControllerDelegate {
    // MARK: - Properties
    /*
    lazy var player = AVPlayer()
    
    var pictureInPictureController: AVPictureInPictureController!
    
    var playerView: PlayerView {
        return self.view as! PlayerView
    }
    
    var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    var playerItem: AVPlayerItem? = nil {
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
                setupPlayerPeriodicTimeObserver()
            }
        }
    }
    
    var timeObserverToken: AnyObject?
    
    // Attempt to load and test these asset keys before playing
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            player.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    var duration: Double {
        guard let currentItem = player.currentItem else { return 0.0 }
        
        return CMTimeGetSeconds(currentItem.duration)
    }
    */
    // MARK: - IBOutlets
    
    @IBOutlet weak var pictureInPictureButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var screenModeButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    // MARK: - Setup
    /*
    private func setupPlayback() {
        
        let movieURL = Bundle.main.url(forResource: "samplemovie", withExtension: "mov")!
        let asset = AVURLAsset(url: movieURL, options: nil)
        /*
         Create a new `AVPlayerItem` and make it our player's current item.
         
         Using `AVAsset` now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's prudent
         to defer our work until the properties we need have been loaded.
         
         These properties can be passed in at initialization to `AVPlayerItem`,
         which are then loaded automatically by `AVPlayer`.
         */
        self.playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: PlayerViewController.assetKeysRequiredToPlay)
    }
    
    private func setupPlayerPeriodicTimeObserver() {
        // Only add the time observer if one hasn't been created yet.
        guard timeObserverToken == nil else { return }
        
        let time = CMTimeMake(1, 1)
        
        // Use a weak self variable to avoid a retain cycle in the block.
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue:DispatchQueue.main) {
            [weak self] time in
            self?.timeSlider.value = Float(CMTimeGetSeconds(time))
            } as AnyObject?
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func setupPictureInPicturePlayback() {
        /*
         Check to make sure Picture in Picture is supported for the current
         setup (application configuration, hardware, etc.).
         */
        if #available(iOS 9.0, *) {
            if AVPictureInPictureController.isPictureInPictureSupported() {
                /*
                 Create `AVPictureInPictureController` with our `playerLayer`.
                 Set self as delegate to receive callbacks for picture in picture events.
                 Add observer to be notified when pictureInPicturePossible changes value,
                 so that we can enable `pictureInPictureButton`.
                 */
                let pipController = AVPictureInPictureController(playerLayer: playerView.playerLayer)
                
                pictureInPictureHelper = PictureInPictureHelper()
                pictureInPictureHelper?.pictureInPictureController = pipController
                
                addObserver(self, forKeyPath: #keyPath(PictureInPictureHelper.pictureInPictureController.pictureInPicturePossible), options: [.new, .initial], context: &playerViewControllerKVOContext)
            }
            else {
                pictureInPictureButton.isEnabled = false
            }
        } else {
            // Fallback on earlier versions
        }
    }
    */
    // MARK: - Actions
    
    @IBAction func closeButtonClicked(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func togglePictureInPictureMode(_ sender: UIButton) {
    }
    
    @IBAction func playPauseButtonClicked(_ sender: UIButton) {
        /*
        if player.rate != 1.0 {
            // Not playing foward, so play.
            
            if currentTime == duration {
                // At end, so got back to beginning.
                currentTime = 0.0
            }
            
            player.play()
        }
        else {
            // Playing, so pause.
            player.pause()
        }
 */
    }
    
    @IBAction func toggleScreenMode(_ sender: UIButton) {

    }
    
    @IBAction func sliderTouchDown(_ sender: UISlider) {
    }
    
    @IBAction func sliderCancel(_ sender: UISlider) {
    }
    
    @IBAction func sliderTouchUp(_ sender: UISlider) {
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
/*
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NotificationMessageWindow.show(message: "画中画模式开始播放")
    }
    

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NotificationMessageWindow.show(message: "画中画模式即将停止")
    }
    

    func picture(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        NotificationMessageWindow.show(message: "画中画模式加载失败: \(error.localizedDescription)")
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
            
            let currentTime = CMTimeGetSeconds(player.currentTime())
            timeSlider.value = hasValidDuration ? Float(currentTime) : 0.0
            
            playPauseButton.isEnabled = hasValidDuration
            timeSlider.isEnabled = hasValidDuration
        }
        else if keyPath == #keyPath(PlayerViewController.player.rate) {
            // Update playPauseButton type.
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).doubleValue
            
            let style: UIBarButtonSystemItem = newRate == 0.0 ? .play : .pause
            let newPlayPauseButton = UIBarButtonItem(barButtonSystemItem: style, target: self, action: #selector(PlayerViewController.playPauseButtonWasPressed(_:)))
            
            // Replace the current button with the updated button in the toolbar.
            var items = toolbar.items!
            
            if let playPauseItemIndex = items.index(of: playPauseButton) {
                items[playPauseItemIndex] = newPlayPauseButton
                
                playPauseButton = newPlayPauseButton
                
                toolbar.setItems(items, animated: false)
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
                handle(error: player.currentItem?.error as NSError?)
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
                            self.handle(error: error)
                            return
                        }
                    }
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        // We can't play this asset.
                        self.handle(error: nil)
                        return
                    }
                    
                    /*
                     The player item is ready to play,
                     setup picture in picture.
                     */
                    if pictureInPictureController == nil {
                        setupPictureInPicturePlayback()
                    }
                }
            }
        }
        else if keyPath == #keyPath(PlayerViewController.pictureInPictureController.pictureInPicturePossible) {
            /* 
             Enable the `pictureInPictureButton` only if `pictureInPicturePossible`
             is true. If this returns false, it might mean that the application
             was not configured as shown in the AppDelegate.
             */
            let newValue = change?[NSKeyValueChangeKey.newKey] as! NSNumber
            let isPictureInPicturePossible: Bool = newValue.boolValue
            
            pictureInPictureButton.isEnabled = isPictureInPicturePossible
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
 */
}

