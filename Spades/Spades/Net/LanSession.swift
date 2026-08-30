import Foundation
import Network

final class LanSession {
    static let serviceType = "_spades._tcp"

    private let queue = DispatchQueue(label: "com.spades.mobile.lan")
    private let onEvent: (LanEvent) -> Void
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private var found: [String: NWBrowser.Result] = [:]
    private var buffers: [String: Data] = [:]
    private var advertisedName: String?
    private var hostDisplayName = "Host"

    init(displayName: String, onEvent: @escaping (LanEvent) -> Void) {
        self.hostDisplayName = displayName.isEmpty ? "Player" : displayName
        self.onEvent = onEvent
    }

    func startHosting(_ name: String) {
        stopDiscovery()
        hostDisplayName = String(name.prefix(24))
        if hostDisplayName.isEmpty { hostDisplayName = "Host" }
        if listener != nil {
            post(.advertisingStarted)
            return
        }
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let listener = try NWListener(using: params)
            var txt = NWTXTRecord()
            txt["n"] = hostDisplayName
            let instance = "spades-\(String(UUID().uuidString.prefix(6)).lowercased())"
            advertisedName = instance
            listener.service = NWListener.Service(name: instance, type: Self.serviceType, txtRecord: txt)
            listener.stateUpdateHandler = { [weak self] state in
                if case .ready = state {
                    self?.post(.advertisingStarted)
                }
                if case .failed(let error) = state {
                    self?.post(.error("Could not host: \(error.localizedDescription)"))
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            post(.error("Could not host: \(error.localizedDescription)"))
        }
    }

    func resumeAdvertising(_ name: String) {
        if listener != nil {
            post(.advertisingStarted)
            return
        }
        startHosting(name)
    }

    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        advertisedName = nil
    }

    func startDiscovery() {
        stopAdvertising()
        stopDiscovery()
        found.removeAll()
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil), using: params)
        browser.browseResultsChangedHandler = { [weak self] _, changes in
            guard let self else { return }
            for change in changes {
                switch change {
                case .added(let result):
                    let id = Self.endpointId(result)
                    if id == self.advertisedName { continue }
                    self.found[id] = result
                    self.post(.endpointFound(id: id, name: Self.tableName(result)))
                case .removed(let result):
                    let id = Self.endpointId(result)
                    self.found.removeValue(forKey: id)
                    self.post(.endpointLost(id: id))
                default:
                    break
                }
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.post(.discoveryStarted)
            }
            if case .failed(let error) = state {
                self?.post(.error("Could not find tables: \(error.localizedDescription)"))
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }

    func join(_ endpointId: String, name: String) {
        guard let result = found[endpointId] else {
            post(.error("Could not join: table is gone. Find tables again."))
            return
        }
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let connection = NWConnection(to: result.endpoint, using: params)
        attach(connection, id: endpointId, announceName: name)
    }

    func send(_ to: String, _ msg: NetMsg) {
        guard let connection = connections[to], let data = NetCodec.encode(msg) else { return }
        sendFrame(connection, data)
    }

    func broadcast(_ msg: NetMsg) {
        guard let data = NetCodec.encode(msg) else { return }
        connections.values.forEach { sendFrame($0, data) }
    }

    func disconnect(_ id: String) {
        connections.removeValue(forKey: id)?.cancel()
        buffers.removeValue(forKey: id)
    }

    func shutdown() {
        stopAdvertising()
        stopDiscovery()
        connections.keys.forEach { disconnect($0) }
        connections.removeAll()
        found.removeAll()
        buffers.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        let id = "tcp-\(UUID().uuidString.prefix(8))"
        attach(connection, id: id, announceName: "Friend")
    }

    private func attach(_ connection: NWConnection, id: String, announceName: String) {
        connections[id] = connection
        buffers[id] = Data()
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.post(.connected(id: id, name: announceName))
                self?.receive(id)
            case .failed, .cancelled:
                self?.connections.removeValue(forKey: id)
                self?.buffers.removeValue(forKey: id)
                self?.post(.disconnected(id: id))
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(_ id: String) {
        guard let connection = connections[id] else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if let content {
                self.buffers[id, default: Data()].append(content)
                self.drain(id)
            }
            if isComplete || error != nil {
                self.connections.removeValue(forKey: id)
                self.buffers.removeValue(forKey: id)
                self.post(.disconnected(id: id))
                return
            }
            self.receive(id)
        }
    }

    private func drain(_ id: String) {
        while var buffer = buffers[id], buffer.count >= 4 {
            let raw = buffer.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            let length = UInt32(bigEndian: raw)
            guard length > 0, length < 2_000_000 else {
                buffers.removeValue(forKey: id)
                return
            }
            if buffer.count < 4 + Int(length) { return }
            buffer.removeFirst(4)
            let payload = buffer.prefix(Int(length))
            buffer.removeFirst(Int(length))
            buffers[id] = buffer
            if let msg = NetCodec.decode(Data(payload)) {
                post(.message(fromId: id, msg: msg))
            }
        }
    }

    private func sendFrame(_ connection: NWConnection, _ data: Data) {
        var length = UInt32(data.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(data)
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }

    private func post(_ event: LanEvent) {
        DispatchQueue.main.async { self.onEvent(event) }
    }

    private static func endpointId(_ result: NWBrowser.Result) -> String {
        if case .service(let name, _, _, _) = result.endpoint {
            return name
        }
        return String(describing: result.endpoint)
    }

    private static func tableName(_ result: NWBrowser.Result) -> String {
        if case .bonjour(let txt) = result.metadata {
            let name = txt.dictionary["n"] ?? ""
            if !name.isEmpty { return name }
        }
        return endpointId(result)
    }
}

enum NetCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func encode(_ msg: NetMsg) -> Data? {
        try? encoder.encode(msg)
    }

    static func decode(_ data: Data) -> NetMsg? {
        try? decoder.decode(NetMsg.self, from: data)
    }
}
