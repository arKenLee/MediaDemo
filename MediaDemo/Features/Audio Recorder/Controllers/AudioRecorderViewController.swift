//
//  AudioRecorderViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

class AudioRecorderViewController: UIViewController {
    
    // MARK: - Properties
    
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
    
    fileprivate var playTimer: Timer?
    fileprivate var sliderDragging = false
    
    fileprivate var recordTimer: Timer?
    fileprivate var recordDuration: TimeInterval = 0
    fileprivate var shouldResumeRecord = false
    
    fileprivate lazy var recordFileName: String = ""
    fileprivate lazy var tempRecordFilePath: URL = URL(fileURLWithPath: "")
    fileprivate lazy var audioSetting: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM, // 录音格式
        AVNumberOfChannelsKey: 1,  // 单声道
//        AVSampleRateKey: 11025,  // 采样率，如果不设置默认为 44100
        
//        AVLinearPCMBitDepthKey: 8, // 线性 PCM 属性，如果不设置默认16位
//        AVLinearPCMIsBigEndianKey: true, // 线性 PCM 属性，如果不设置默认 false，即“小端字节序”
    ]
    
    fileprivate var audioRecorder: AVAudioRecorder?
    
    // 处理回调
    fileprivate var handleBlockStack: [(Void) -> Void] = []
    
    fileprivate lazy var ioQueue: DispatchQueue = DispatchQueue(label: "com.arkenlee.recorderIOQueue")
    
    fileprivate var isUserInteractionEnabled: Bool = true {
        didSet {
            menuButton.isEnabled = isUserInteractionEnabled
            playButton.isEnabled = isUserInteractionEnabled
            recordButton.isEnabled = isUserInteractionEnabled
            controlSlider.isEnabled = isUserInteractionEnabled
            finishRecordButton.isEnabled = isUserInteractionEnabled
        }
    }
    
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        controlSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot"), for: .normal)
        controlSlider.setThumbImage(#imageLiteral(resourceName: "player_slider_dot_big"), for: .highlighted)
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if #available(iOS 9, *) {
            if !audioSession.availableCategories.contains(AVAudioSessionCategoryRecord) {
                NotificationMessageWindow.show(message: "当前设备不支持录音功能")
            }
        }
        
        if !audioSession.recordPermission().contains(.granted) {
            audioSession.requestRecordPermission { _ in }
        }
        
        setupRecordInfo()
        
        registerNotification()
    }
    
    deinit {
        invalidateRecorderTimer()
        unregisterNotification()
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
}



// MARK: - Actions
extension AudioRecorderViewController {

    // 点击背景
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
    
    // 点击菜单
    @IBAction func menuButtonClicked(_ sender: UIButton) {
    }
    
    // 点击播放按钮
    @IBAction func playButtonClicked(_ sender: UIButton) {
        if globalPlayer.type == .recordPlayer && globalPlayer.audioPlayerIsPlaying {
            pausePlay()
        } else {
            startPlay()
        }
    }
    
    // 点击录音按钮
    @IBAction func recordButtonClicked(_ sender: UIButton) {
        guard enableRecord() else {
            return
        }
        
        if let recorder = audioRecorder, recorder.isRecording {
            pauseRecord()
        } else {
            startRecord()
        }
    }
    
    // 点击停止录音按钮
    @IBAction func finishRecordButtonClicked(_ sender: UIButton) {
        if FileManager.default.fileExists(atPath: tempRecordFilePath.path) || audioRecorder != nil {
            showConfirmPanel(title: "确定要结束录音吗？", message: nil) { (result) in
                if result {
                    self.handleBlockStack.append { [weak self] in
                        self?.saveRecordFile()
                    }
                    
                    self.stopRecord()
                }
            }
        } else {
            NotificationMessageWindow.show(message: "还没有开始录音")
        }
    }
    
    // 开始滑动滑竿
    @IBAction func controlSliderTouchDown(_ sender: ControlSlider) {
        sliderDragging = true
    }
    
    // 取消滑竿操作
    @IBAction func controlSliderTouchCancel(_ sender: ControlSlider) {
        sliderDragging = false
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .recordPlayer {
            sender.value = Float(player.currentTime)
        }
    }
    
    // 滑竿滑动完毕
    @IBAction func controlSliderTouchUp(_ sender: ControlSlider) {
        sliderDragging = false
        
        if let player = globalPlayer.audioPlayer, globalPlayer.type == .recordPlayer, player.duration > 0 {
            player.currentTime = TimeInterval(sender.value)
            currentTimeLabel.text = player.currentTime.playTimeString
        }
    }
}


// MARK: - Record

extension AudioRecorderViewController: AVAudioRecorderDelegate {
    
    // MARK: AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        activityIndicator.stopAnimating()
        
        recordButton.setImage(#imageLiteral(resourceName: "record_button_start"), for: .normal)
        isUserInteractionEnabled = true
        
        invalidateRecorderTimer()
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                NotificationMessageWindow.show(message: "播放录音时设置音频会话类别失败: \(error.localizedDescription)")
            }
        }
        
        if handleBlockStack.count > 0 {
            let handleBlock = handleBlockStack.removeLast()
            handleBlock()
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        NotificationMessageWindow.show(message: "录音编码失败, player: \(recorder), error: \(error?.localizedDescription ?? "未知错误")")
        
        audioRecorder = nil
        recordButton.setImage(#imageLiteral(resourceName: "record_button_start"), for: .normal)
        isUserInteractionEnabled = true
        
        invalidateRecorderTimer()
        
        if let timer = recordTimer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    NotificationMessageWindow.show(message: "播放录音时设置音频会话类别失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: fileprivate
    
    fileprivate func enableRecord() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        
        let enableRecord = audioSession.recordPermission().contains(.granted)
        
        if !enableRecord {
            audioSession.requestRecordPermission { [weak self] (result) in
                if !result {
                    self?.showConfirmPanel(title: "需要开启麦克风权限", message: nil, cancelTitle: "暂不设置", confirmTitle: "去设置") { (confirm) in
                        if confirm {
                            let url = URL(string: UIApplicationOpenSettingsURLString)!
                            if #available(iOS 10.0, *) {
                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            } else {
                                UIApplication.shared.openURL(url)
                            }
                            
                        }
                    }
                }
            }
        }
        
        return enableRecord
    }
    
    // 设置录音信息
    fileprivate func setupRecordInfo() {
        recordFileName = Date().recordFileName
        
        let filename = (recordFileName as NSString).appendingPathExtension("m4a")!
        
        if let url = urlForTempAudioRecordFile(with: filename) {
            tempRecordFilePath = url
        } else {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            tempRecordFilePath = tempDir.appendingPathComponent(filename)
        }
        
        recordDuration = 0
        controlSlider.value = 0
        currentTimeLabel.text = placeholderPlayTimeString
        durationLabel.text = placeholderPlayTimeString
        
        nameLabel.text = recordFileName
        recordDurationLabel.text = recordDuration.recordDurationString
    }
    
    // 开始录音
    fileprivate func startRecord() {
        
        if let recorder = audioRecorder, recorder.isRecording {
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if audioSession.category != AVAudioSessionCategoryRecord {
            do {
                try audioSession.setCategory(AVAudioSessionCategoryRecord)
            } catch let error {
                NotificationMessageWindow.show(message: "设置音频会话类别为[录音]类别失败: \(error.localizedDescription)")
                return
            }
        }
        
        var prepareToRecord = false
        
        if audioRecorder != nil {
            prepareToRecord = audioRecorder!.prepareToRecord()
        } else {
            
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
                let recorder = try AVAudioRecorder(url: path, settings: audioSetting)
                recorder.isMeteringEnabled = true
                recorder.delegate = self
                prepareToRecord = recorder.prepareToRecord()
                audioRecorder = recorder
            } catch let error {
                NotificationMessageWindow.show(message: "初始化录音失败: \(error.localizedDescription)")
                return
            }
        }

        if !prepareToRecord {
            audioRecorder = nil
            NotificationMessageWindow.show(message: "录音准备失败")
            return
        }
        
        // 准备开始录音，停止其他播放
        NotificationCenter.default.post(name: AllPauseNotification, object: self)
        
        if audioRecorder!.record() {
            
            recordButton.setImage(#imageLiteral(resourceName: "record_button_pause"), for: .normal)
            
            controlSlider.value = 0
            controlSlider.isEnabled = false
            playButton.isEnabled = false
            menuButton.isEnabled = false
            finishRecordButton.isEnabled = false
            
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power0")
            recordPowerImageView.isHidden = false
            
            if let timer = recordTimer, timer.isValid {
                timer.fireDate = Date.distantPast
            } else {
                recordTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(updateRecordUI), userInfo: nil, repeats: true)
                RunLoop.current.add(recordTimer!, forMode: .commonModes)
            }
                        
        } else {
            audioRecorder = nil
            NotificationMessageWindow.show(message: "录音失败")
        }
    }
    
    // 暂停录音
    fileprivate func pauseRecord() {
        recordButton.setImage(#imageLiteral(resourceName: "record_button_start"), for: .normal)
        isUserInteractionEnabled = true
        recordPowerImageView.isHidden = true
        
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.pause()
        }
        
        if let timer = recordTimer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
    }
    
    // 停止录音
    fileprivate func stopRecord() {
        recordPowerImageView.isHidden = true
        if let recorder = audioRecorder {
            
            handleBlockStack.append { [weak self] in
                self?.spliceRecordFile()
            }
            
            activityIndicator.startAnimating()
            isUserInteractionEnabled = false
            
            recorder.stop()
        } else {
            if handleBlockStack.count > 0 {
                let handleBlock = handleBlockStack.removeLast()
                handleBlock()
            }
        }
    }
    
    // 保存录音文件
    fileprivate func saveRecordFile() {
        pausePlay()
        
        let configureTextFieldHandle = { (textField: UITextField) in
            textField.text = self.recordFileName
        }
        
        showAlert(title: "保存录音文件", message: nil, actionTitles: ["删除", "保存"], hasDestructiveAction: false, configureTextFieldHandles: [configureTextFieldHandle]) { (index: Int, textFields: [UITextField]?) in
            if index == 0 {
                self.deleteTempRecordFile()
            } else {
                let fileName = textFields?.first?.text ?? self.recordFileName
                self.moveRecordFile(name: fileName)
            }
        }
    }
    
    // 销毁录音定时器
    fileprivate func invalidateRecorderTimer() {
        if let timer = recordTimer, timer.isValid {
            timer.invalidate()
        }
        
        recordTimer = nil
    }
    
    // MARK: private
    
    // 拼接录音文件
    private func spliceRecordFile() {
        guard let recorder = audioRecorder else {
            return
        }
        
        activityIndicator.startAnimating()
        isUserInteractionEnabled = false
        
        ioQueue.async { [weak self] in
            guard let sSelf = self else { return }
            
            let sourceURL: URL
            var hasTempFile = false
            
            if FileManager.default.fileExists(atPath: sSelf.tempRecordFilePath.path) {
                let tempFilePath = sSelf.tempRecordFilePath.deletingPathExtension().path + "_temp.m4a"
                sourceURL = URL(fileURLWithPath: tempFilePath)
                do {
                    try FileManager.default.moveItem(at: sSelf.tempRecordFilePath, to: sourceURL)
                    hasTempFile = true
                } catch {}
            } else {
                sourceURL = sSelf.tempRecordFilePath
            }
            
            pieceAudio(url1: sourceURL, audio2: recorder.url, outputURL: sSelf.tempRecordFilePath) { (success) in
                DispatchQueue.main.async { [weak self] in
                    guard let ssSelf = self else {
                        return
                    }
                    
                    if hasTempFile {
                        try? FileManager.default.removeItem(at: sourceURL)
                    }
                    
                    ssSelf.audioRecorder?.deleteRecording()
                    ssSelf.audioRecorder = nil
                    ssSelf.activityIndicator.stopAnimating()
                    ssSelf.isUserInteractionEnabled = true
                    
                    if ssSelf.handleBlockStack.count > 0 {
                        let handleBlock = ssSelf.handleBlockStack.removeLast()
                        handleBlock()
                    }
                }
            }
        }
    }
    
    // 删除录音文件
    private func deleteTempRecordFile() {
        let tempRecordFileDirectory = tempRecordFilePath.deletingLastPathComponent()
        
        if FileManager.default.fileExists(atPath: tempRecordFileDirectory.path) {
            do {
                try FileManager.default.removeItem(at: tempRecordFileDirectory)
            } catch let error {
                NotificationMessageWindow.show(message: "删除录音文件失败: \(error.localizedDescription)")
            }
        }
        
        audioRecorder = nil
        setupRecordInfo()
    }
    
    // 移动录音文件
    private func moveRecordFile(name: String) {
        let filename = (name as NSString).appendingPathExtension("m4a") ?? name
        guard let destination = urlForAudioRecordFile(with: filename) else {
            return
        }
        
        do {
            try FileManager.default.moveItem(at: tempRecordFilePath, to: destination)
            deleteTempRecordFile()
        } catch let error {
            NotificationMessageWindow.show(message: "保存录音文件失败: \(error.localizedDescription)")
        }
    }
    
    // 刷新录音UI
    @objc private func updateRecordUI() {
        guard let audioRecorder = audioRecorder else {
            return
        }
        
        recordDuration += 0.1
        recordDurationLabel.text = recordDuration.recordDurationString
        
        // 更新测量值
        audioRecorder.updateMeters()
        
        // 取得第一个通道的分贝峰值
        let power = audioRecorder.peakPower(forChannel: 0)
//        print("record power: \(power)")
        if power > 0 {
            recordPowerImageView.image = #imageLiteral(resourceName: "record_icon_power4")
            return
        }
        
        let lowPassResults:Double = pow(Double(10), Double(0.01 * power))
//        print("lowPassResults: \(lowPassResults)")
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
}



// MARK: - Play
extension AudioRecorderViewController: AVAudioPlayerDelegate {
    
    // MARK: AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
        recordButton.isEnabled = true
        invalidatePlayerTimer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        NotificationMessageWindow.show(message: "录音文件解码失败, player: \(player), error: \(error?.localizedDescription ?? "未知错误")")
        
        playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
        recordButton.isEnabled = true
        invalidatePlayerTimer()
    }
    
    
    // MARK: fileprivate
    
    // 播放录音
    fileprivate func startPlay() {
        if let player = globalPlayer.audioPlayer,
            player.isPlaying,
            globalPlayer.type == .recordPlayer {
            return
        }
        
        handleBlockStack.append { [ weak self] in
            guard let sSelf = self else { return }
            
            do {
                let player = try AVAudioPlayer(contentsOf: sSelf.tempRecordFilePath)
                player.delegate = self
                
                if player.prepareToPlay() {
                    
                    sSelf.currentTimeLabel.text = player.currentTime.playTimeString
                    sSelf.durationLabel.text = player.duration.playTimeString
                    sSelf.controlSlider.value = 0
                    sSelf.controlSlider.minimumValue = 0
                    sSelf.controlSlider.maximumValue = Float(player.duration)
                    globalPlayer.audioPlayer = player
                    globalPlayer.type = .recordPlayer
                    
                    if player.play() {
                        sSelf.playButton.setImage(#imageLiteral(resourceName: "audio_button_pause"), for: .normal)
                        sSelf.recordButton.isEnabled = false
                        
                        if let timer = sSelf.playTimer, timer.isValid {
                            timer.fireDate = Date.distantPast
                        } else {
                            sSelf.playTimer = Timer(timeInterval: 0.1, target: sSelf, selector: #selector(sSelf.updatePlayProgress), userInfo: nil, repeats: true)
                            RunLoop.current.add(sSelf.playTimer!, forMode: .commonModes)
                        }
                    }
                } else {
                    NotificationMessageWindow.show(message: "准备播放录音失败")
                }
                
            } catch let error {
                sSelf.currentTimeLabel.text = placeholderPlayTimeString
                sSelf.durationLabel.text = placeholderPlayTimeString
                sSelf.controlSlider.value = 0
                sSelf.controlSlider.minimumValue = 0
                sSelf.controlSlider.maximumValue = 1
                NotificationMessageWindow.show(message: "初始化录音播放失败: \(error.localizedDescription)")
            }

        }
        
        stopRecord()
    }
    
    // 暂停播放录音
    fileprivate func pausePlay() {
        guard GlobalPlayer.shared.type == .recordPlayer else {
            return
        }
        
        if let audioPlayer = GlobalPlayer.shared.audioPlayer, audioPlayer.isPlaying {
            audioPlayer.pause()
        }
        
        playButton.setImage(#imageLiteral(resourceName: "audio_button_play"), for: .normal)
        recordButton.isEnabled = true
        
        if let timer = playTimer, timer.isValid {
            timer.fireDate = Date.distantFuture
        }
    }
    
    // 销毁播放定时器
    fileprivate func invalidatePlayerTimer() {
        if let timer = playTimer, timer.isValid {
            timer.invalidate()
        }
        
        playTimer = nil
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
}


// MARK: - Notification
extension AudioRecorderViewController {
    
    fileprivate func registerNotification() {
        let audioSession = AVAudioSession.sharedInstance()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self,
                                       selector: #selector(globalPlayerTypeWillChange(_:)),
                                       name: GlobalPlayerTypeWillChange,
                                       object: globalPlayer)
        
        notificationCenter.addObserver(self,
                                       selector: #selector(handleInterruption(_:)),
                                       name: .AVAudioSessionInterruption,
                                       object: audioSession)
        
        notificationCenter.addObserver(self,
                                       selector: #selector(handleRouteChange(_:)),
                                       name: .AVAudioSessionRouteChange,
                                       object: audioSession)
        
        notificationCenter.addObserver(self,
                                       selector: #selector(pauseAudio(_:)),
                                       name: AllPauseNotification,
                                       object: nil)
    }
    
    fileprivate func unregisterNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    
    @objc private func globalPlayerTypeWillChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let newType = userInfo[GlobalPlayerNewTypeItem] as? AudioPlayerType else {
                return
        }
        
        if newType != .recordPlayer {
            pausePlay()
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
            }
            
            pausePlay()
            pauseRecord()
            
        case .ended:
            if let optionsNumber = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber
            {
                let options = AVAudioSessionInterruptionOptions(rawValue: optionsNumber.uintValue)
                
                if options.contains(.shouldResume) && shouldResumeRecord {
                    startRecord()
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
    
    @objc private func pauseAudio(_ notification: Notification) {
        pausePlay()
    }
}
