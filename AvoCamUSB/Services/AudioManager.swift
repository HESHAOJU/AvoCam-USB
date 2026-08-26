//
//  AudioManager.swift
//  AvoCamUSB
//
//  音频采集与 AAC 编码
//

import AVFoundation
import AudioToolbox

/// 音频管理器 - 采集麦克风并编码为 AAC ADTS 格式
class AudioManager: NSObject {

    private let audioEngine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let audioQueue = DispatchQueue(label: "com.avocamusb.audio")

    /// 编码后的 AAC ADTS 数据回调
    var onEncodedAudio: ((Data) -> Void)?

    /// 音频配置
    private let sampleRate: Double = 48000
    private let channels: AVAudioChannelCount = 1 // 单声道
    private let bitrate: Int = 64000 // 64 kbps
    private let frameSize: AVAudioFrameCount = 1024 // AAC 每帧 1024 采样

    private var isRunning = false

    // MARK: - 配置

    /// 配置音频会话和引擎
    func configure() {
        audioQueue.async { [weak self] in
            self?.setupAudio()
        }
    }

    private func setupAudio() {
        // 配置音频会话
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(sampleRate)
            try session.setActive(true)
        } catch {
            print("[AudioManager] 配置音频会话失败: \(error)")
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // 创建 AAC 输出格式
        guard let aacFormat = AVAudioFormat(settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitrate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]) else {
            print("[AudioManager] 创建 AAC 格式失败")
            return
        }

        // 创建音频转换器（PCM → AAC）
        converter = AVAudioConverter(from: inputFormat, to: aacFormat)
        converter?.bitRate = bitrate

        // 安装输入回调
        inputNode.installTap(onBus: 0, bufferSize: frameSize, format: inputFormat) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer, time: time)
        }

        print("[AudioManager] 音频引擎已配置: \(Int(sampleRate))Hz, \(channels)声道, \(bitrate/1000)kbps AAC")
    }

    // MARK: - 控制

    /// 开始采集
    func start() {
        audioQueue.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            do {
                try self.audioEngine.start()
                self.isRunning = true
                print("[AudioManager] 音频采集已启动")
            } catch {
                print("[AudioManager] 启动音频引擎失败: \(error)")
            }
        }
    }

    /// 停止采集
    func stop() {
        audioQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.isRunning = false
            print("[AudioManager] 音频采集已停止")
        }
    }

    // MARK: - 音频处理

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let converter = converter else { return }

        // 创建 AAC 输出缓冲区（压缩格式）
        let outputCapacity = AVAudioFrameCount(buffer.frameLength)
        guard let outputBuffer = AVAudioCompressedBuffer(
            format: converter.outputFormat,
            packetCapacity: 1,
            maximumPacketSize: converter.outputFormat.maximumPacketSize
        ) else {
            print("[AudioManager] 创建输出缓冲区失败")
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            if let error = error {
                print("[AudioManager] AAC 编码错误: \(error)")
            }
            return
        }

        guard outputBuffer.packetCount > 0 else { return }

        // 获取 AAC 数据
        let aacData = Data(bytes: outputBuffer.data.assumingMemoryBound(to: UInt8.self),
                           count: Int(outputBuffer.byteLength))

        guard !aacData.isEmpty else { return }

        // 生成 ADTS 头并组合
        let adtsHeader = AudioManager.makeADTSHeader(
            packetLength: aacData.count,
            sampleRateIndex: 3, // 48000 Hz
            channelConfig: Int(channels)
        )

        var adtsPacket = Data()
        adtsPacket.append(adtsHeader)
        adtsPacket.append(aacData)

        DispatchQueue.main.async { [weak self] in
            self?.onEncodedAudio?(adtsPacket)
        }
    }

    deinit {
        stop()
    }
}

// MARK: - AAC ADTS 工具

extension AudioManager {

    /// 生成 AAC ADTS 头（7 字节）
    /// - Parameters:
    ///   - packetLength: AAC 帧数据长度（不含 ADTS 头）
    ///   - sampleRateIndex: 采样率索引（0=96000, 1=88200, 2=64000, 3=48000, 4=44100...）
    ///   - channelConfig: 声道配置（1=单声道, 2=立体声）
    static func makeADTSHeader(packetLength: Int, sampleRateIndex: Int = 3, channelConfig: Int = 1) -> Data {
        var header = Data(count: 7)

        let fullLength = packetLength + 7 // ADTS 头 + AAC 数据

        // Byte 0: 同步字高8位 0xFF
        header[0] = 0xFF

        // Byte 1: 同步字低4位(1111) + MPEG-4(0) + Layer(00) + protection_absent(1) = 0xF1
        header[1] = 0xF1

        // Byte 2: profile(2bit, AAC-LC=1) + sampling_freq_index(4bit) + private_bit(0) + channel_config高1位
        // profile = 1 (AAC-LC), 左移6位
        header[2] = UInt8((0x01 << 6) | (sampleRateIndex << 2) | (channelConfig >> 2))

        // Byte 3: channel_config低2位 + original_copy(0) + home(0) + copyright_id_bit(0) + copyright_id_start(0) + frame_length高2位
        header[3] = UInt8((channelConfig & 0x03) << 6)
        header[3] |= UInt8((fullLength >> 11) & 0x03)

        // Byte 4: frame_length 中8位
        header[4] = UInt8((fullLength >> 3) & 0xFF)

        // Byte 5: frame_length 低3位 + buffer_fullness 高5位
        header[5] = UInt8(((fullLength & 0x07) << 5) | 0x1F)

        // Byte 6: buffer_fullness 低6位 + number_of_raw_data_blocks(2bit, 0)
        header[6] = 0xFC // 0x1F << 2 = 0xFC，buffer_fullness 全1 + 0 blocks

        return header
    }
}
