//
//  ScreenDimmer.swift
//  AvoCamUSB
//
//  息屏管理器 - 降低屏幕亮度+全屏黑色覆盖+防误触
//

import UIKit
import SwiftUI

/// 息屏管理器
class ScreenDimmer: NSObject, ObservableObject {

    static let shared = ScreenDimmer()

    @Published var isDimmed = false

    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var dimmerWindow: UIWindow?
    private var lastTapTime: Date?

    // 中央唤醒区域大小（屏幕中心的正方形区域）
    private let wakeAreaSize: CGFloat = 120

    private override init() {}

    /// 开启息屏（降低亮度+全屏黑色覆盖+防误触）
    func engage() {
        guard !isDimmed else { return }
        isDimmed = true

        // 保存原始亮度并降到最低
        originalBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 0.0

        // 创建全屏黑色覆盖窗口
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        window.windowLevel = .statusBar + 1
        window.isUserInteractionEnabled = true
        window.makeKeyAndVisible()

        // 添加双击手势（快速双击屏幕中央唤醒）
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.numberOfTapsRequired = 2
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)

        dimmerWindow = window

        // 禁止自动锁屏
        UIApplication.shared.isIdleTimerDisabled = true

        lastTapTime = nil
        avoPrint("[ScreenDimmer] 息屏已开启（防误触：快速双击屏幕中央唤醒）")
    }

    /// 关闭息屏（恢复亮度+移除覆盖）
    func disengage() {
        guard isDimmed else { return }
        isDimmed = false

        // 恢复亮度
        UIScreen.main.brightness = originalBrightness

        // 移除覆盖窗口
        dimmerWindow?.isHidden = true
        dimmerWindow = nil

        // 恢复自动锁屏
        UIApplication.shared.isIdleTimerDisabled = false

        lastTapTime = nil
        avoPrint("[ScreenDimmer] 息屏已关闭")
    }

    /// 切换息屏状态
    func toggle() {
        if isDimmed {
            disengage()
        } else {
            engage()
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let window = dimmerWindow else { return }

        let location = gesture.location(in: window)
        let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)

        // 判断是否在中央唤醒区域内
        let halfSize = wakeAreaSize / 2
        let isInWakeArea = abs(location.x - center.x) <= halfSize &&
                            abs(location.y - center.y) <= halfSize

        if isInWakeArea {
            avoPrint("[ScreenDimmer] 检测到中央区域双击，唤醒屏幕")
            disengage()
        } else {
            avoPrint("[ScreenDimmer] 点击在唤醒区域外，忽略（防误触）")
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ScreenDimmer: UIGestureRecognizerDelegate {
    // 允许手势识别，同时其他位置触摸不传递到下层
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }
}
