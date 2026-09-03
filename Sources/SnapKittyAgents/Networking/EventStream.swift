// WebSocket event stream — /api/events/stream
// Unknown event categories must not crash — raw payload preserved

import Foundation

@MainActor
final class EventStream: NSObject, ObservableObject {
    private let url: URL
    private let apiKey: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: Error?

    private var eventHandlers: [(BrowserEvent) -> Void] = []
    private var reconnectTask: Task<Void, Never>?
    private var reconnectDelay: TimeInterval = 1.0

    enum ConnectionState { case disconnected, connecting, connected, reconnecting }

    init(url: URL, apiKey: String?) {
        self.url = url
        self.apiKey = apiKey
    }

    func connect() {
        guard connectionState == .disconnected else { return }
        connectionState = .connecting
        openSocket()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    func onEvent(_ handler: @escaping (BrowserEvent) -> Void) {
        eventHandlers.append(handler)
    }

    // MARK: - Private

    private func openSocket() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session

        var req = URLRequest(url: url)
        if let key = apiKey { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }

        let task = session.webSocketTask(with: req)
        self.webSocketTask = task
        task.resume()
        receiveLoop()
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveLoop()
            case .failure(let error):
                Task { @MainActor in
                    self.lastError = error
                    self.connectionState = .reconnecting
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):   data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default:    return
        }

        // Decode — unknown event types must not crash
        guard let event = try? JSONDecoder.hk.decode(BrowserEvent.self, from: data) else {
            // Preserve raw payload for debugging
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            SKLogger.debug("EventStream: undecodable event: \(raw.prefix(200))")
            return
        }

        Task { @MainActor in
            self.eventHandlers.forEach { $0(event) }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.reconnectDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.reconnectDelay = min(self.reconnectDelay * 2, 30.0)
                self.webSocketTask = nil
                self.openSocket()
            }
        }
    }
}

extension EventStream: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                                 didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            self.connectionState = .connected
            self.reconnectDelay = 1.0
            SKLogger.info("EventStream: connected to \(self.url)")
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                                 didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            self.connectionState = .disconnected
            SKLogger.info("EventStream: closed (\(closeCode))")
        }
    }
}
