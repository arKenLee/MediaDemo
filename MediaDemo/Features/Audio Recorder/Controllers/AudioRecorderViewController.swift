//
//  AudioRecorderViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

class AudioRecorderViewController: UIViewController, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var recordDurationLabel: UILabel!
    @IBOutlet weak var recordPowerImageView: UIImageView!
    
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var controlSlider: ControlSlider!
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var finishRecordButton: UIButton!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var playTimer: Timer?
    private var recordTimer: Timer?
    private var sliderDragging = false
    private var shouldResumeRecord = false
    
    private var recordDuration: TimeInterval = 0
    
    private var recordFileName: String!
    private var tempRecordFilePath: URL!
    private lazy var audioSetting: [String: Any] = {
        /*
        return [AVFormatIDKey: kAudioFormatLinearPCM,   // 录音格式
            AVNumberOfChannelsKey: 1,     // 录音采样率
            AVLinearPCMBitDepthKey: 8,    // 采样点数（8、16、24、32）
            AVLinearPCMIsFloatKey: true]  // 使用浮点数采样
        */
        return [AVFormatIDKey: kAudioFormatLinearPCM]
    }()
    
    private var audioRecorder: AVAudioRecorder?
    private var handleBlockStack: [(Void) -> Void] = []
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        controlSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot"), for: .normal)
        controlSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot_big"), for: .highlighted)
        
        setupRecordInfo()
        
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
    
    // MARK: - Record
    
    // 设置录音信息
    private func setupRecordInfo() {
        recordFileName = Date().recordFileName
        
        if let url = urlForTempAudioRecordFile(with: recordFileName) {
            tempRecordFilePath = url
        } else {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            tempRecordFilePath = tempDir.appendingPathComponent(self.recordFileName)
        }
        
        recordDuration = 0
        
        nameLabel.text = recordFileName
        recordDurationLabel.text = recordDuration.recordDurationString
    }
    
    // 开始录音
    private func startRecord() {
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryRecord {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryRecord)
            } catch let error {
                NotificationMessageWindow.show(message: "设置音频会话类别为[录音]类别失败: \(error.localizedDescription)")
                return
            }
        }
        
        handleBlockStack.append { [weak self] in
            guard let sSelf = self else { return }
            
            let recordDirectory: URL
            if let url = tempAudioRecordFileDirectory() {
                recordDirectory = url
            } else {
                recordDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            }
            
            let count = (FileManager.default.subpaths(atPath: recordDirectory.path)?.count ?? 0) + 1
            let filename = "\(count).caf"
            let path = recordDirectory.appendingPathComponent(filename)
            
            do {
                let recorder = try AVAudioRecorder(url: path, settings: sSelf.audioSetting)
                recorder.isMeteringEnabled = true
                recorder.delegate = sSelf
                
                if recorder.prepareToRecord() {
                    if recorder.record() {
                        
                        sSelf.recordButton.setImage(#imageLiteral(resourceName: "record_button_pause"), for: .normal)
                        sSelf.playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
                        sSelf.playButton.isEnabled = false
                        sSelf.finishRecordButton.isEnabled = false
                        
                        if let timer = sSelf.recordTimer, timer.isValid {
                            timer.fireDate = Date.distantPast
                        } else {
                            sSelf.recordTimer = Timer(timeInterval: 0.1, target: sSelf, selector: #selector(sSelf.updateRecordUI), userInfo: nil, repeats: true)
                            RunLoop.current.add(sSelf.recordTimer!, forMode: .commonModes)
                        }
                        
                        sSelf.audioRecorder = recorder
                        
                    } else {
                        sSelf.audioRecorder = nil
                        NotificationMessageWindow.show(message: "录音失败")
                    }
                } else {
                    sSelf.audioRecorder = nil
                    NotificationMessageWindow.show(message: "录音准备失败")
                }
                
            } catch let error {
                sSelf.audioRecorder = nil
                NotificationMessageWindow.show(message: "初始化录音失败: \(error.localizedDescription)")
            }
        }
        
        pauseRecord()
    }
    
    // 暂停录音
    private func pauseRecord() {
        if let audioRecorder = audioRecorder, audioRecorder.isRecording {
            
            handleBlockStack.append { [weak self] in
                self?.spliceRecordFile()
            }
            
            activityIndicator.startAnimating()
            menuButton.isEnabled = false
            playButton.isEnabled = false
            recordButton.isEnabled = false
            finishRecordButton.isEnabled = false
            
            audioRecorder.stop()
            
        } else {
            if handleBlockStack.count > 0 {
                let handleBlock = handleBlockStack.removeLast()
                handleBlock()
            }
        }
    }
    
    // 拼接录音文件
    private func spliceRecordFile() {
        activityIndicator.startAnimating()
        menuButton.isEnabled = false
        playButton.isEnabled = false
        recordButton.isEnabled = false
        finishRecordButton.isEnabled = false
        
        DispatchQueue.global().async {
            // TODO: 拼接录音文件
            
            
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else {
                    return
                }
                
                sSelf.activityIndicator.stopAnimating()
                sSelf.menuButton.isEnabled = true
                sSelf.playButton.isEnabled = true
                sSelf.recordButton.isEnabled = true
                sSelf.finishRecordButton.isEnabled = true
                
                if sSelf.handleBlockStack.count > 0 {
                    let handleBlock = sSelf.handleBlockStack.removeLast()
                    handleBlock()
                }
            }
        }
    }
    
    @objc private func updateRecordUI() {
        guard let audioRecorder = audioRecorder else {
            return
        }
        
        recordDuration += 0.1
        recordDurationLabel.text = recordDuration.recordDurationString
        
        // 更新测量值
        audioRecorder.updateMeters()
        
        // 取得第一个通道的音频，注意音频强度范围时-160到0
        let power = audioRecorder.peakPower(forChannel: 0)
        print("record power: \(power)")
        
        let lowPassResults:Double = pow(Double(10), Double(0.05 * power))
        switch lowPassResults {
        case 0...0.20 :
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power0")
        case 0.21...0.40 :
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power1")
        case 0.41...0.60 :
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power2")
        case 0.61...0.80 :
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power3")
        case 0.81...1.00 :
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power4")
        default:
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power0")
        }
    }
    
    // MARK: - Play
    
    // 播放录音
    private func startPlay() {
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                NotificationMessageWindow.show(message: "播放录音时设置音频会话类别失败: \(error.localizedDescription)")
            }
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: tempRecordFilePath)
            player.delegate = self
            
            if player.prepareToPlay() {
            
                currentTimeLabel.text = player.currentTime.playTimeString
                durationLabel.text = player.duration.playTimeString
                controlSlider.value = 0
                controlSlider.minimumValue = 0
                controlSlider.maximumValue = Float(player.duration)
                GlobalPlayer.shared.audioPlayer = player
                GlobalPlayer.shared.type = .recordPlayer
                
                if player.play() {
                    playButton.setImage(#imageLiteral(resourceName: "audio_button_pause"), for: .normal)
                    recordButton.isEnabled = false
                    finishRecordButton.isEnabled = false
                    
                    if let timer = playTimer, timer.isValid {
                        timer.fireDate = Date.distantPast
                    } else {
                        playTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(updatePlayProgress), userInfo: nil, repeats: true)
                        RunLoop.current.add(playTimer!, forMode: .commonModes)
                    }
                }
            } else {
                NotificationMessageWindow.show(message: "准备播放录音失败")
            }
            
        } catch let error {
            currentTimeLabel.text = "--:--:--"
            durationLabel.text = "--:--:--"
            controlSlider.value = 0
            controlSlider.minimumValue = 0
            controlSlider.maximumValue = 1
            NotificationMessageWindow.show(message: "初始化录音播放失败: \(error.localizedDescription)")
        }
    }
    
    // 暂停播放录音
    private func pausePlay() {
        guard GlobalPlayer.shared.type == .recordPlayer else {
            return
        }
        
        if let audioPlayer = GlobalPlayer.shared.audioPlayer, audioPlayer.isPlaying {
            audioPlayer.pause()
        }
        
        playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
        recordButton.isEnabled = true
        finishRecordButton.isEnabled = true
        
        if let timer = playTimer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
    }
    
    // 更新录音进度条
    @objc private func updatePlayProgress() {
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .recordPlayer {
            
            currentTimeLabel.text = player.currentTime.playTimeString
            
            if !sliderDragging {
                controlSlider.value = Float(player.currentTime)
            }
        }
    }
   
    
    // MARK: - Actions

    @IBAction func tappedBackground(_ sender: UITapGestureRecognizer) {
        guard let tabBar = self.tabBarController?.tabBar else { return }
        
        let duration = 0.5
        let tabBarOffset: CGFloat = 40.0
        
        self.view.isUserInteractionEnabled = false
        
        if tabBar.alpha < 1e-6 {
            // 显示 Tab Bar
            UIView.animate(withDuration: duration, animations: { [unowned self] in
                tabBar.alpha = 1
                tabBar.frame.origin.y -= tabBarOffset
                self.setNeedsStatusBarAppearanceUpdate()
                }, completion: { [unowned self] (_) in
                    self.view.isUserInteractionEnabled = true
            })
        } else {
            // 隐藏 Tab Bar
            UIView.animate(withDuration: duration, animations: { [unowned self] in
                tabBar.alpha = 0
                tabBar.frame.origin.y += tabBarOffset
                self.setNeedsStatusBarAppearanceUpdate()
                }, completion: { [unowned self] (_) in
                    self.view.isUserInteractionEnabled = true
            })
        }
    }
    
    @IBAction func menuButtonClicked(_ sender: UIButton) {
    }
    
    @IBAction func playButtonClicked(_ sender: UIButton) {
        if globalPlayer.type == .recordPlayer && globalPlayer.audioPlayerIsPlaying {
            pausePlay()
        } else {
            startPlay()
        }
    }
    
    @IBAction func recordButtonClicked(_ sender: UIButton) {
    }
    
    @IBAction func finishRecordButtonClicked(_ sender: UIButton) {
    }
    
    @IBAction func controlSliderTouchDown(_ sender: ControlSlider) {
        sliderDragging = true
    }
    
    @IBAction func controlSliderTouchCancel(_ sender: ControlSlider) {
        sliderDragging = false
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .recordPlayer {
            sender.value = Float(player.currentTime)
        }
    }
    
    
    @IBAction func controlSliderTouchUp(_ sender: ControlSlider) {
        sliderDragging = false
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .recordPlayer, player.duration > 0 {
            player.currentTime = TimeInterval(sender.value)
            currentTimeLabel.text = player.currentTime.playTimeString
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
        recordButton.isEnabled = true
        finishRecordButton.isEnabled = true
        
        if let timer = playTimer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        NotificationMessageWindow.show(message: "录音文件解码失败, player: \(player), error: \(error?.localizedDescription ?? "未知错误")")
    }

    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        activityIndicator.stopAnimating()
        menuButton.isEnabled = true
        playButton.isEnabled = true
        recordButton.isEnabled = true
        finishRecordButton.isEnabled = true
        
        if handleBlockStack.count > 0 {
            let handleBlock = handleBlockStack.removeLast()
            handleBlock()
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        NotificationMessageWindow.show(message: "录音编码失败, player: \(recorder), error: \(error?.localizedDescription ?? "未知错误")")
    }
    
    // MARK: - Notification
    
    private func registerNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        
        NotificationCenter.default.addObserver(self, selector: #selector(globalPlayerTypeWillChange(_:)), name: GlobalPlayerTypeWillChange, object: globalPlayer)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: .AVAudioSessionInterruption, object: audioSession)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: .AVAudioSessionRouteChange, object: audioSession)
    }
    
    private func deregisterNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        
        NotificationCenter.default.removeObserver(self, name: GlobalPlayerTypeWillChange, object: globalPlayer)
        NotificationCenter.default.removeObserver(self, name: .AVAudioSessionInterruption, object: audioSession)
        NotificationCenter.default.removeObserver(self, name: .AVAudioSessionRouteChange, object: audioSession)
    }
    
    @objc private func globalPlayerTypeWillChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let newType = userInfo[GlobalPlayerNewTypeItem] as? AudioPlayerType else {
                return
        }
        
        if newType != .recordPlayer {
            if let audioPlayer = GlobalPlayer.shared.audioPlayer, audioPlayer.isPlaying {
                audioPlayer.pause()
            }
            
            playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
            recordButton.isEnabled = true
            finishRecordButton.isEnabled = true
            
            if let timer = playTimer, timer.isValid {
                timer.fireDate = Date.distantFuture
            }
            
            pauseRecord()
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
        
        switch type {
        case .began:
            
            if let audioRecorder = audioRecorder, audioRecorder.isRecording {
                shouldResumeRecord = true
                audioRecorder.pause()
            }
            
            playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
            recordButton.setImage(#imageLiteral(resourceName: "record_button_start"), for: .normal)
            
            playButton.isEnabled = true
            recordButton.isEnabled = true
            finishRecordButton.isEnabled = true
            
            if let timer = playTimer, timer.isValid {
                timer.fireDate = Date.distantFuture
            }
            
            if let timer = recordTimer, timer.isValid {
                timer.fireDate = Date.distantFuture
            }
            
        case .ended:
            if let optionsNumber = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber
            {
                let options = AVAudioSessionInterruptionOptions(rawValue: optionsNumber.uintValue)
                
                if options.contains(.shouldResume) && shouldResumeRecord {
                    if let audioRecorder = audioRecorder {
                        if audioRecorder.record() {
                            recordButton.setImage(#imageLiteral(resourceName: "record_button_pause"), for: .normal)
                            playButton.isEnabled = false
                            finishRecordButton.isEnabled = false
                        }
                    }
                    
                }
            }
            
            shouldResumeRecord = false
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
                
                if globalPlayerType == .recordPlayer && globalPlayer.audioPlayerIsPlaying {
                    pausePlay()
                }
            }
        default:
            break
        }
    }

}
