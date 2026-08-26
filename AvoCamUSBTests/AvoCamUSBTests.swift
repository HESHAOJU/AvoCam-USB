//
//  AvoCamUSBTests.swift
//  AvoCamUSBTests
//

import XCTest
@testable import AvoCamUSB

final class AvoCamUSBTests: XCTestCase {

    func testPortalProtocolVideoPacket() throws {
        let testData = Data([0x00, 0x00, 0x00, 0x01, 0x65, 0x88, 0x80, 0x40])
        let packet = PortalSender.makeVideoPacket(testData)

        // 验证包头：version=1
        let version = packet.withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(version, 1)

        // 验证 type=101
        let type = packet.dropFirst(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(type, 101)

        // 验证 payloadSize
        let payloadSize = packet.dropFirst(12).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(payloadSize, UInt32(testData.count))

        // 验证总长度 = 16字节头 + 载荷
        XCTAssertEqual(packet.count, 16 + testData.count)
    }

    func testPortalProtocolAudioPacket() throws {
        let testData = Data([0xFF, 0xF1, 0x50, 0x40, 0x00, 0x01, 0xFC])
        let packet = PortalSender.makeAudioPacket(testData)

        // 验证 type=102
        let type = packet.dropFirst(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(type, 102)
    }

    func testADTSHeader() throws {
        let header = AudioManager.makeADTSHeader(packetLength: 100, sampleRateIndex: 3, channelConfig: 1)

        // 验证同步字
        XCTAssertEqual(header[0], 0xFF)
        XCTAssertEqual(header[1] & 0xF0, 0xF0) // 同步字低4位

        // 验证 MPEG-4
        XCTAssertEqual(header[1] & 0x08, 0x00)

        // 验证 protection_absent=1
        XCTAssertEqual(header[1] & 0x01, 0x01)

        // 验证长度为7字节
        XCTAssertEqual(header.count, 7)
    }
}
