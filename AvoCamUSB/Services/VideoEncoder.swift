//
//  VideoEncoder.swift
//  AvoCamUSB
//
//  视频硬编码 - VideoToolbox H.264
//

import AVFoundation
import CoreVideo
import VideoToolbox

/// H.264 视频编码器
class VideoEncoder {

    private var compressionSession: VTCompressionSession?
    private let encoderQueue = DispatchQueue(label: "com.avocamusb.encoder.video")

    /// 编码后的 H.264 Annex-B 数据回调
    var onEncodedFrame: ((Data) -> Void)?

    /// 当前配置
    private(set) var width: Int = 1920
    private(set) var height: Int = 1080
    private(set) var frameRate: Int = 30
    private(set) var bitrate: Int = 8_000_000 // 8 Mbps

    // MARK: - 配置与创建

    /// 配置编码器
    func configure(width: Int, height: Int, frameRate: Int, bitrate: Int = 8_000_000) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitrate = bitrate

        encoderQueue.async { [weak self] in
            self?.destroySession()
            self?.createSession()
        }
    }

    private func createSession() {
        var status: OSStatus = noErr

        // 创建压缩会话（直接传入输出回调）
        var session: VTCompressionSession?
        status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ] as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: { (outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer) in
                guard let sampleBuffer = sampleBuffer, status == noErr else { return }
                guard let refCon = outputCallbackRefCon else { return }
                let encoder = Unmanaged<VideoEncoder>.fromOpaque(refCon).takeUnretainedValue()
                encoder.handleEncodedSampleBuffer(sampleBuffer, infoFlags: infoFlags)
            },
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let compressionSession = session else {
            print("[VideoEncoder] 创建压缩会话失败: \(status)")
            return
        }

        self.compressionSession = compressionSession

        // 设置编码属性
        let properties: [NSString: Any] = [
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_AutoLevel,
            kVTCompressionPropertyKey_RealTime: true,
            kVTCompressionPropertyKey_AverageBitRate: bitrate,
            kVTCompressionPropertyKey_DataRateLimits: [bitrate / 8, 1] as CFArray, // 字节/秒
            kVTCompressionPropertyKey_MaxKeyFrameInterval: frameRate, // 每秒一个关键帧
            kVTCompressionPropertyKey_AllowFrameReordering: false, // 无 B 帧
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ]
        ]

        for (key, value) in properties {
            VTSessionSetProperty(compressionSession, key: key, value: value as CFTypeRef)
        }

        // 准备编码
        VTCompressionSessionPrepareToEncodeFrames(compressionSession)

        print("[VideoEncoder] 编码器已创建: \(width)x\(height) @ \(frameRate)fps, \(bitrate / 1_000_000)Mbps")
    }

    private func destroySession() {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }

    // MARK: - 编码

    /// 编码一帧（CVPixelBuffer）
    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        encoderQueue.async { [weak self] in
            guard let self = self, let session = self.compressionSession else { return }

            let duration = CMTime(value: 1, timescale: CMTimeScale(self.frameRate))

            var status: OSStatus = noErr
            var flags: VTEncodeInfoFlags = []

            status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: presentationTime,
                duration: duration,
                frameProperties: nil,
                sourceFrameRefcon: nil,
                infoFlagsOut: &flags
            )

            if status != noErr {
                print("[VideoEncoder] 编码帧失败: \(status)")
            }
        }
    }

    // MARK: - 编码结果处理

    private func handleEncodedSampleBuffer(_ sampleBuffer: CMSampleBuffer, infoFlags: VTEncodeInfoFlags) {
        // 检查是否是关键帧
        let isKeyFrame = !infoFlags.contains(.frameDropped)

        // 获取编码数据
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == noErr, let pointer = dataPointer else { return }

        // 转换为 Data
        let h264Data = Data(bytes: pointer, count: length)

        // 处理 NAL 单元（AVCC 格式 → Annex-B 格式）
        // AVCC: 4字节长度前缀 + NAL数据
        // Annex-B: 0x00000001 起始码 + NAL数据
        let annexBData = convertAVCCToAnnexB(h264Data, isKeyFrame: isKeyFrame)

        DispatchQueue.main.async { [weak self] in
            self?.onEncodedFrame?(annexBData)
        }
    }

    /// 将 AVCC 格式的 H.264 数据转换为 Annex-B 格式
    private func convertAVCCToAnnexB(_ data: Data, isKeyFrame: Bool) -> Data {
        var result = Data()
        var offset = 0

        while offset + 4 <= data.count {
            // 读取 4 字节的 NAL 单元长度（大端序）
            let nalLength = data.subdata(in: offset..<offset+4).withUnsafeBytes {
                $0.load(as: UInt32.self).bigEndian
            }
            offset += 4

            guard offset + Int(nalLength) <= data.count else { break }

            // 写入 Annex-B 起始码 0x00000001
            result.append(contentsOf: [0x00, 0x00, 0x00, 0x01])

            // 写入 NAL 单元数据
            result.append(data.subdata(in: offset..<offset+Int(nalLength)))
            offset += Int(nalLength)
        }

        return result
    }

    deinit {
        destroySession()
    }
}
