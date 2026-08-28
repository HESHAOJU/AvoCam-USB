//
//  BackgroundManager.swift
//  AvoCamUSB
//
//  后台保活管理器 - 通过播放静音音频 + 后台任务保持 App 在后台运行
//

import Foundation
import AVFoundation
import UIKit

/// 后台保活管理器
class BackgroundManager: NSObject {

    static let shared = BackgroundManager()

    private var audioPlayer: AVAudioPlayer?
    private var isActive = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
        // 监听音频中断
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    /// 启动后台保活
    func start() {
        guard !isActive else { return }
        isActive = true

        // 1. 配置音频会话为播放模式，允许后台播放
        configureAudioSession()

        // 2. 开始播放静音音频（主要保活机制）
        startSilencePlayback()

        // 3. 申请后台任务（额外保障）
        beginBackgroundTask()

        print("[BackgroundManager] 后台保活已启动")
    }

    /// 停止后台保活
    func stop() {
        guard isActive else { return }
        isActive = false

        // 停止静音播放
        audioPlayer?.stop()
        audioPlayer = nil

        // 结束后台任务
        endBackgroundTask()

        // 停用音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[BackgroundManager] 停止音频会话失败: \(error)")
        }

        print("[BackgroundManager] 后台保活已停止")
    }

    // MARK: - 音频会话配置

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback 类别允许后台音频播放
            // .mixWithOthers 允许与其他应用混音
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[BackgroundManager] 配置音频会话失败: \(error)")
        }
    }

    // MARK: - 静音音频播放

    private func startSilencePlayback() {
        let silenceData = createSilenceAudio(duration: 1.0)
        do {
            audioPlayer = try AVAudioPlayer(data: silenceData)
            audioPlayer?.numberOfLoops = -1 // 无限循环
            audioPlayer?.volume = 0.0 // 静音
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[BackgroundManager] 创建音频播放器失败: \(error)")
        }
    }

    /// 创建静音音频数据（WAV 格式）
    private func createSilenceAudio(duration: TimeInterval) -> Data {
        let sampleRate: Double = 44100.0
        var channels: UInt16 = 1
        var bitsPerSample: UInt16 = 16
        var byteRate = UInt32(sampleRate * Double(channels) * Double(bitsPerSample) / 8)
        var blockAlign = channels * bitsPerSample / 8
        var dataSize = UInt32(duration * sampleRate) * UInt32(blockAlign)
        let totalSize = 44 + dataSize

        var data = Data(capacity: Int(totalSize))

        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        var fileSize = totalSize - 8
        data.append(Data(bytes: &fileSize, count: 4))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        var fmtSize: UInt32 = 16
        data.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat: UInt16 = 1 // PCM
        data.append(Data(bytes: &audioFormat, count: 2))
        data.append(Data(bytes: &channels, count: 2))
        var sampleRateValue = UInt32(sampleRate)
        data.append(Data(bytes: &sampleRateValue, count: 4))
        data.append(Data(bytes: &byteRate, count: 4))
        data.append(Data(bytes: &blockAlign, count: 2))
        data.append(Data(bytes: &bitsPerSample, count: 2))

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(Data(bytes: &dataSize, count: 4))

        // 静音数据（全0）
        data.append(Data(count: Int(dataSize)))

        return data
    }

    // MARK: - 后台任务

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AvoCamUSBKeepAlive") { [weak self] in
            // 后台任务即将过期，重新申请
            self?.beginBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - 音频中断处理

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // 音频中断开始（如来电），暂停播放
            print("[BackgroundManager] 音频中断开始")
        case .ended:
            // 音频中断结束，恢复播放
            print("[BackgroundManager] 音频中断结束，恢复播放")
            if isActive {
                configureAudioSession()
                startSilencePlayback()
            }
        @unknown default:
            break
        }
    }
}
