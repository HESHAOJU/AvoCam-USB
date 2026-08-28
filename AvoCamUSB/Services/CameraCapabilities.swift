//
//  CameraCapabilities.swift
//  AvoCamUSB
//
//  设备摄像头能力检测 - 自动选择最高规格
//

import AVFoundation

/// 摄像头格式信息
struct CameraFormatInfo: CustomStringConvertible {
    let format: AVCaptureDevice.Format
    let width: Int
    let height: Int
    let maxFrameRate: Double
    let isHDR: Bool

    var description: String {
        return "\(width)x\(height) @ \(Int(maxFrameRate))fps\(isHDR ? " HDR" : "")"
    }
}

/// 摄像头能力检测器
class CameraCapabilities {

    /// 获取指定位置摄像头的所有支持格式
    static func getSupportedFormats(position: AVCaptureDevice.Position) -> [CameraFormatInfo] {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            return []
        }
        return device.formats.compactMap { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            // 获取该格式支持的最大帧率
            let maxFrameRate = format.videoSupportedFrameRateRanges
                .map { $0.maxFrameRate }
                .max() ?? 30
            let isHDR = format.isVideoHDRSupported
            return CameraFormatInfo(
                format: format,
                width: Int(dims.width),
                height: Int(dims.height),
                maxFrameRate: maxFrameRate,
                isHDR: isHDR
            )
        }
    }

    /// 自动选择最高规格的格式
    /// 优先级：分辨率 > 帧率 > HDR
    static func selectBestFormat(position: AVCaptureDevice.Position) -> CameraFormatInfo? {
        let formats = getSupportedFormats(position: position)
        guard !formats.isEmpty else { return nil }

        // 按分辨率降序，再按帧率降序，再按 HDR 优先排序
        let sorted = formats.sorted { a, b in
            if a.width * a.height != b.width * b.height {
                return a.width * a.height > b.width * b.height
            }
            if a.maxFrameRate != b.maxFrameRate {
                return a.maxFrameRate > b.maxFrameRate
            }
            return a.isHDR && !b.isHDR
        }

        return sorted.first
    }

    /// 获取所有支持的格式列表（去重，按分辨率和帧率排序）
    static func getAllFormats(position: AVCaptureDevice.Position) -> [CameraFormatInfo] {
        let formats = getSupportedFormats(position: position)
        // 去重：相同分辨率和帧率的只保留一个
        var seen = Set<String>()
        var unique = [CameraFormatInfo]()
        for format in formats {
            let key = "\(format.width)x\(format.height)@\(Int(format.maxFrameRate))"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(format)
            }
        }
        // 按分辨率降序，再按帧率降序排序
        return unique.sorted { a, b in
            if a.width * a.height != b.width * b.height {
                return a.width * a.height > b.width * b.height
            }
            return a.maxFrameRate > b.maxFrameRate
        }
    }

    /// 获取设备型号名称
    static func getDeviceName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// 获取所有可用摄像头（前后摄、多镜头）
    static func getAvailableCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }
}
