import Foundation

// MARK: - Class

public class Awake {

    // Public

    @discardableResult public static func target(device: Device) -> Error? {
        var sock: Int32
        var target = sockaddr_in()

        target.sin_family = sa_family_t(AF_INET)
        target.sin_addr.s_addr = inet_addr(device.broadcastAddr)

        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        target.sin_port = isLittleEndian ? _OSSwapInt16(device.port) : device.port

        // Setup the packet socket
        sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if sock < .zero {
            let err = String(utf8String: strerror(errno)) ?? ""
            return WakeError.socketSetupFailed(reason: err)
        }

        let packet = Awake.createMagicPacket(mac: device.MAC)
        let sockaddrLen = socklen_t(MemoryLayout<sockaddr>.stride)
        let intLen = socklen_t(MemoryLayout<Int>.stride)

        // Set socket options
        var broadcast = 1
        if setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, intLen) == -1 {
            close(sock)
            let err = String(utf8String: strerror(errno)) ?? ""
            return WakeError.setSocketOptionsFailed(reason: err)
        }

        // Send magic packet

        var targetCast = unsafeBitCast(
            target,
            to: sockaddr.self
        )

        if sendto(sock, packet, packet.count, .zero, &targetCast, sockaddrLen) != packet.count {
            close(sock)
            let err = String(utf8String: strerror(errno)) ?? ""
            return WakeError.sendMagicPacketFailed(reason: err)
        }

        close(sock)

        return nil
    }

    // Fileprivate

    fileprivate static func createMagicPacket(mac: String) -> [CUnsignedChar] {
        var buffer = [CUnsignedChar]()

        // Create header
        for _ in 1...6 {
            buffer.append(0xFF)
        }

        let components = mac.components(separatedBy: ":")
        let numbers = components.map {
            return strtoul($0, nil, 16)
        }

        // Repeat MAC address 16 times
        for _ in 1...16 {
            for number in numbers {
                buffer.append(CUnsignedChar(number))
            }
        }

        return buffer
    }
}

// MARK: - Structs

public extension Awake {
    struct Device {
        public let MAC: String
        public let broadcastAddr: String
        public let port: UInt16

        public init(
            MAC: String,
            broadcastAddr: String,
            port: UInt16 = 9
        ) {
            self.MAC = MAC
            self.broadcastAddr = broadcastAddr
            self.port = port
        }
    }
}

// MARK: - Enums

public extension Awake {
    enum WakeError: Error {
        case socketSetupFailed(reason: String)
        case setSocketOptionsFailed(reason: String)
        case sendMagicPacketFailed(reason: String)
    }
}
