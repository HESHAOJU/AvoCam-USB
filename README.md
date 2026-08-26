# AvoCamUSB - iPhone USB 虚拟摄像头

通过 USB 数据线将 iPhone 摄像头作为电脑虚拟摄像头，用于直播。无水印、支持最高分辨率和帧率、支持音频传输。

## 功能特性

- ✅ USB 有线连接，低延迟高带宽
- ✅ 自动检测 iPhone 摄像头最高规格（4K 60fps）
- ✅ 自动对焦、光学防抖、自动曝光、自动白平衡（原生功能自动生效）
- ✅ H.264 硬编码（VideoToolbox）
- ✅ AAC 音频编码（麦克风同步传输）
- ✅ 前后摄像头切换
- ✅ 纯中文界面
- ✅ 无水印

## 系统要求

- iPhone：iOS 15.0+
- 电脑：Windows 10/11
- 软件：OBS Studio + obs-ios-camera-source 插件
- 驱动：iTunes / Apple Devices（usbmuxd 服务）

## 通信协议

iPhone 端监听 **2345 端口**，OBS 插件通过 usbmuxd 隧道连接。

数据包格式（Portal Protocol，16字节头+载荷）：
```
version(4) + type(4) + tag(4) + payloadSize(4) + payload
```
- type=101：视频包（H.264 Annex-B 格式）
- type=102：音频包（AAC ADTS 格式）

## 编译（GitHub Actions 云编译，无需 Mac）

### 1. 推送代码到 GitHub

```bash
cd ios-app
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/AvoCamUSB.git
git push -u origin main
```

### 2. 触发编译

推送后 GitHub Actions 会自动开始编译（约 5-10 分钟）。

也可以手动触发：仓库页面 → Actions → Build iOS App → Run workflow

### 3. 下载 ipa

编译完成后：
- 仓库页面 → Actions → 最新的 build 任务
- 页面底部 Artifacts → 下载 `AvoCamUSB.ipa`

## 安装到 iPhone

使用 SideStore 或 AltStore 安装 ipa：

1. 电脑端安装 SideStore（推荐，无需电脑常驻）
2. iPhone 安装 SideStore
3. 在 SideStore 中导入下载的 ipa 文件
4. 点击安装，7天后需要刷新签名（免费 Apple ID）

## 使用方法

1. 用 USB 数据线连接 iPhone 到电脑
2. iPhone 上点"信任此电脑"
3. 打开 AvoCamUSB App，点"开始推流"
4. 电脑上打开 OBS，来源 → + → iOS Camera
5. 启动 OBS 虚拟摄像头
6. 在抖音直播伴侣中选择 OBS Virtual Camera 作为摄像头

## 项目结构

```
AvoCamUSB/
├── AvoCamUSBApp.swift          # App 入口
├── Models/
│   └── PortalProtocol.swift     # Portal 协议封装
├── Services/
│   ├── CameraCapabilities.swift # 设备能力检测
│   ├── CaptureManager.swift     # 摄像头+麦克风采集
│   ├── VideoEncoder.swift       # H.264 硬编码
│   ├── AudioManager.swift       # AAC 音频编码
│   ├── NetworkServer.swift      # TCP 监听 2345 端口
│   └── StreamController.swift   # 流控制器
├── Views/
│   └── ContentView.swift        # SwiftUI 界面
└── Resources/
    └── Info.plist               # 权限配置
```

## 许可证

GPL-2.0（基于 obs-ios-camera-source 二次开发）
