//
//  PortalProtocol.swift
//  AvoCamUSB
//
//  Portal 协议数据封装 - 与 obs-ios-camera-source 插件通信
//

import Foundation

/// Portal 协议数据包类型
enum PortalPacketType: UInt32 {
    case video = 101   // 视频包（H.264/HEVC Annex-B 格式）
    case audio = 102   // 音频包（AAC ADTS 格式）
}

/// Portal 协议帧头（16 字节）
/// 格式：version(4) + type(4) + tag(4) + payloadSize(4) + payload
struct PortalFrame {
    let version: UInt32 = 1
    let type: UInt32
    let tag: UInt32 = 0
    let payload: Data

    /// 序列化为可发送的 Data
    func serialized() -> Data {
        var data = Data()
        // 小端序写入
        withUnsafeBytes(of: version.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: type.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: tag.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(payload.count).littleEndian) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }
}

/// Portal 协议发送器
class PortalSender {
    /// 发送视频帧
    static func makeVideoPacket(_ data: Data) -> Data {
        let frame = PortalFrame(type: PortalPacketType.video.rawValue, payload: data)
        return frame.serialized()
    }

    /// 发送音频帧
    static func makeAudioPacket(_ data: Data) -> Data {
        let frame = PortalFrame(type: PortalPacketType.audio.rawValue, payload: data)
        return frame.serialized()
    }
}
