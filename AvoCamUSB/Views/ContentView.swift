//
//  ContentView.swift
//  AvoCamUSB
//
//  主界面 - SwiftUI 纯中文
//

import SwiftUI

/// 主界面
struct ContentView: View {

    @StateObject private var streamController = StreamController()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // 标题
                    Text("iPhone USB 虚拟摄像头")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)

                    Text("通过 USB 数据线将 iPhone 摄像头作为电脑虚拟摄像头")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // 状态卡片
                    statusCard

                    // 设备信息
                    deviceInfoCard

                    // 控制按钮
                    controlButtons

                    // 使用说明
                    usageGuide

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("AvoCam USB", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - 状态卡片

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: streamController.isStreaming ? "video.fill" : "video.slash")
                    .font(.title2)
                    .foregroundColor(streamController.isStreaming ? .green : .red)

                Text(streamController.isStreaming ? "正在推流" : "未推流")
                    .font(.headline)

                Spacer()

                Circle()
                    .fill(streamController.isConnected ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                Text(streamController.isConnected ? "电脑已连接" : "等待电脑连接")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("视频帧")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(streamController.videoFramesSent)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("音频帧")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(streamController.audioFramesSent)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 设备信息

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("设备信息", systemImage: "info.circle")
                .font(.headline)

            Divider()

            HStack {
                Text("设备型号")
                    .foregroundColor(.secondary)
                Spacer()
                Text(streamController.deviceName)
                    .fontWeight(.medium)
            }

            HStack {
                Text("当前规格")
                    .foregroundColor(.secondary)
                Spacer()
                Text(streamController.currentFormat)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }

            HStack {
                Text("连接方式")
                    .foregroundColor(.secondary)
                Spacer()
                Text("USB 有线")
                    .fontWeight(.medium)
            }

            HStack {
                Text("监听端口")
                    .foregroundColor(.secondary)
                Spacer()
                Text("2345")
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 控制按钮

    private var controlButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                if streamController.isStreaming {
                    streamController.stop()
                } else {
                    streamController.start()
                }
            }) {
                HStack {
                    Image(systemName: streamController.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(streamController.isStreaming ? "停止推流" : "开始推流")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(streamController.isStreaming ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            HStack(spacing: 12) {
                Button(action: {
                    streamController.switchCamera()
                }) {
                    Label("切换摄像头", systemImage: "camera.rotate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .disabled(!streamController.isStreaming)

                Button(action: {
                    streamController.forceKeyFrame()
                }) {
                    Label("强制关键帧", systemImage: "key")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .disabled(!streamController.isStreaming)
            }
        }
    }

    // MARK: - 使用说明

    private var usageGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("使用说明", systemImage: "questionmark.circle")
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                stepView(number: 1, text: "用数据线将 iPhone 连接到电脑")
                stepView(number: 2, text: "在 iPhone 上点击「信任此电脑」")
                stepView(number: 3, text: "确保电脑已安装 iTunes 或 Apple Devices")
                stepView(number: 4, text: "点击「开始推流」按钮")
                stepView(number: 5, text: "在电脑端 OBS 中添加「iOS Camera」来源")
                stepView(number: 6, text: "启动 OBS 虚拟摄像头，在抖音直播伴侣中选择")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func stepView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
