//
//  StreamController.swift
//  AvoCamUSB
//
//  流控制器 - 协调采集、编码、网络发送
//

import Foundation
import AVFoundation
import CoreVideo

/// 流控制器 - 协调所有模块
class StreamController: ObservableObject {

    // 模块
    private let captureManager = CaptureManager()
    private let videoEncoder = VideoEncoder()
    private let audioManager = AudioManager()
    private let networkServer = NetworkServer()

    // 状态
    @Published var isStreaming: Bool = false
    @Published var isConnected: Bool = false
    @Published var currentFormat: String = "检测中..."
    @Published var deviceName: String = ""
    @Published var videoFramesSent: Int = 0
    @Published var audioFramesSent: Int = 0

    init() {
        setupCallbacks()
        deviceName = CameraCapabilities.getDeviceName()
    }

    // MARK: - 设置回调

    private func setupCallbacks() {
        // 视频帧采集 → 编码
        captureManager.onVideoFrame = { [weak self] pixelBuffer, timestamp in
            self?.videoEncoder.encode(pixelBuffer: pixelBuffer, presentationTime: timestamp)
        }

        // 视频编码完成 → 发送
        videoEncoder.onEncodedFrame = { [weak self] h264Data in
            self?.networkServer.sendVideo(h264Data)
            DispatchQueue.main.async {
                self?.videoFramesSent += 1
            }
        }

        // 音频采集编码 → 发送
        audioManager.onEncodedAudio = { [weak self] aacData in
            self?.networkServer.sendAudio(aacData)
            DispatchQueue.main.async {
                self?.audioFramesSent += 1
            }
        }

        // 网络连接状态
        networkServer.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isConnected = connected
            }
        }
    }

    // MARK: - 控制

    /// 开始直播流
    func start() {
        guard !isStreaming else { return }

        // 1. 配置摄像头（自动选最高规格）
        captureManager.configure(position: .back)

        // 2. 等待格式配置完成后配置编码器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // 获取当前格式信息
            let formatDesc = self.captureManager.currentFormatDescription
            self.currentFormat = formatDesc

            // 解析分辨率配置编码器
            if let info = self.captureManager.currentFormatInfo {
                self.videoEncoder.configure(
                    width: info.width,
                    height: info.height,
                    frameRate: Int(info.maxFrameRate),
                    bitrate: 8_000_000
                )
            }
        }

        // 3. 配置音频
        audioManager.configure()

        // 4. 启动网络服务
        networkServer.start()

        // 5. 延迟启动采集（等待配置完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.captureManager.start()
            self?.audioManager.start()
            self?.isStreaming = true
            print("[StreamController] 直播流已启动")
        }
    }

    /// 停止直播流
    func stop() {
        guard isStreaming else { return }

        captureManager.stop()
        audioManager.stop()
        networkServer.stop()

        isStreaming = false
        videoFramesSent = 0
        audioFramesSent = 0
        print("[StreamController] 直播流已停止")
    }

    /// 切换前后摄像头
    func switchCamera() {
        captureManager.switchCamera()
        // 重新配置编码器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let info = self.captureManager.currentFormatInfo else { return }
            self.currentFormat = self.captureManager.currentFormatDescription
            self.videoEncoder.configure(
                width: info.width,
                height: info.height,
                frameRate: Int(info.maxFrameRate),
                bitrate: 8_000_000
            )
        }
    }

    /// 强制关键帧
    func forceKeyFrame() {
        videoEncoder.forceKeyFrame()
    }
}
