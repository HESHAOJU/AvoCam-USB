//
//  AvoCamUSBApp.swift
//  AvoCamUSB
//
//  App 入口
//

import SwiftUI

@main
struct AvoCamUSBApp: App {

    // 保持流控制器的生命周期
    @StateObject private var streamController = StreamController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(streamController)
        }
    }
}
