//
//  AvoCamUSBApp.swift
//  AvoCamUSB
//
//  App 入口
//

import SwiftUI

@main
struct AvoCamUSBApp: App {

    // 保持流控制器的生命周期（唯一实例）
    @StateObject private var streamController = StreamController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(streamController)
                .onAppear {
                    // 启动时自动推流（如果用户开启了自动启动）
                    streamController.autoStartIfNeeded()
                }
        }
    }
}
