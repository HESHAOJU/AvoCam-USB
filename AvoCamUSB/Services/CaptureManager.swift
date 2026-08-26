//
//  CaptureManager.swift
//  AvoCamUSB
//
//  摄像头采集管理 - AVFoundation
//

import AVFoundation
import CoreVideo

/// 摄像头采集管理器
class CaptureManager: NSObject {

    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.avocamusb.capture.session")
    private let videoQueue = DispatchQueue(label: "com.avocamusb.capture.video")
    private let audioQueue = DispatchQueue(label: "com.avocamusb.capture.audio")

    /// 视频帧回调（NV12 格式的 CVPixelBuffer）
    var onVideoFrame: ((CVPixelBuffer, CMTime) -> Void)?
    /// 音频帧回调（CMSampleBuffer）
    var onAudioFrame: ((CMSampleBuffer) -> Void)?

    /// 当前采集的摄像头位置
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    /// 当前格式信息
    private(set) var currentFormatInfo: CameraFormatInfo?

    // MARK: - 初始化与配置

    /// 配置采集会话（自动选择最高规格）
    func configure(position: AVCaptureDevice.Position = .back) {
        currentPosition = position
        sessionQueue.async { [weak self] in
            self?.setupSession(position: position)
        }
    }

    private func setupSession(position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // 清理旧的输入输出
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        // 设置会话预设（使用 high，因为我们通过 activeFormat 手动设置最高规格）
        captureSession.sessionPreset = .high

        // 获取摄像头设备
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("[CaptureManager] 无法获取摄像头设备")
            return
        }

        // 选择最高规格格式
        guard let bestFormat = CameraCapabilities.selectBestFormat(position: position) else {
            print("[CaptureManager] 无法获取支持的格式")
            return
        }
        currentFormatInfo = bestFormat

        do {
            // 锁定配置
            try device.lockForConfiguration()

            // 设置活动格式
            device.activeFormat = bestFormat.format

            // 设置最大帧率
            if let frameRateRange = bestFormat.format.videoSupportedFrameRateRanges.first(where: {
                $0.maxFrameRate == bestFormat.maxFrameRate
            }) {
                device.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
                device.activeVideoMaxFrameDuration = frameRateRange.maxFrameDuration
            }

            // 自动对焦、自动曝光、自动白平衡（系统默认开启，这里显式确认）
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }

            device.unlockForConfiguration()

            print("[CaptureManager] 已配置摄像头: \(bestFormat)")
        } catch {
            print("[CaptureManager] 配置摄像头失败: \(error)")
            return
        }

        // 添加视频输入
        do {
            let videoInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("[CaptureManager] 添加视频输入失败: \(error)")
        }

        // 添加音频输入（麦克风）
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            } catch {
                print("[CaptureManager] 添加音频输入失败: \(error)")
            }
        }

        // 配置视频输出
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        // 配置音频输出
        audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
        }

        // 配置连接（方向等）
        if let connection = videoDataOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }

    // MARK: - 控制

    /// 开始采集
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            print("[CaptureManager] 采集已启动")
        }
    }

    /// 停止采集
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            print("[CaptureManager] 采集已停止")
        }
    }

    /// 切换前后摄像头
    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
        configure(position: newPosition)
    }

    /// 获取当前分辨率和帧率描述
    var currentFormatDescription: String {
        guard let info = currentFormatInfo else { return "未配置" }
        return "\(info.width)x\(info.height) @ \(Int(info.maxFrameRate))fps"
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            onVideoFrame?(pixelBuffer, timestamp)
        } else if output == audioDataOutput {
            onAudioFrame?(sampleBuffer)
        }
    }
}
