//
//  NetworkServer.swift
//  AvoCamUSB
//
//  网络服务 - 监听 2345 端口，通过 USB 隧道与 OBS 插件通信
//

import Network
import Foundation

/// 网络服务器 - TCP 监听 2345 端口
class NetworkServer {

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.avocamusb.network")

    /// 监听端口
    let port: UInt16 = 2345

    /// 连接状态回调
    var onConnectionStateChanged: ((Bool) -> Void)?
    /// 当前是否有客户端连接
    private(set) var isConnected: Bool = false

    // MARK: - 启动与停止

    /// 启动 TCP 监听
    func start() {
        queue.async { [weak self] in
            self?.setupListener()
        }
    }

    /// 停止监听
    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.connections.forEach { $0.cancel() }
            self.connections.removeAll()
            self.listener?.cancel()
            self.listener = nil
            self.isConnected = false
            self.onConnectionStateChanged?(false)
            print("[NetworkServer] 已停止监听")
        }
    }

    private func setupListener() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("[NetworkServer] 正在监听端口 \(self?.port ?? 0)")
                case .failed(let error):
                    print("[NetworkServer] 监听失败: \(error)")
                case .cancelled:
                    print("[NetworkServer] 监听已取消")
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener.start(queue: queue)
        } catch {
            print("[NetworkServer] 创建监听器失败: \(error)")
        }
    }

    // MARK: - 连接处理

    private func handleNewConnection(_ connection: NWConnection) {
        print("[NetworkServer] 新客户端连接")

        connections.append(connection)
        isConnected = true
        onConnectionStateChanged?(true)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[NetworkServer] 客户端连接就绪")
            case .failed(let error):
                print("[NetworkServer] 客户端连接失败: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                print("[NetworkServer] 客户端连接已取消")
                self?.removeConnection(connection)
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func removeConnection(_ connection: NWConnection) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.connections.removeAll { $0 === connection }
            if self.connections.isEmpty {
                self.isConnected = false
                self.onConnectionStateChanged?(false)
            }
        }
    }

    // MARK: - 发送数据

    /// 向所有连接的客户端发送数据
    func send(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self, !self.connections.isEmpty else { return }

            for connection in self.connections {
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("[NetworkServer] 发送数据失败: \(error)")
                    }
                })
            }
        }
    }

    /// 发送视频包（Portal 协议封装）
    func sendVideo(_ h264Data: Data) {
        let packet = PortalSender.makeVideoPacket(h264Data)
        send(packet)
    }

    /// 发送音频包（Portal 协议封装）
    func sendAudio(_ aacData: Data) {
        let packet = PortalSender.makeAudioPacket(aacData)
        send(packet)
    }
}
