import ReplayKit
import VideoToolbox
import CoreImage
import Foundation

class SocketConnection {
    private let filePath: String
    var socketHandle: Int32 = -1
    
    init(filePath: String) {
        self.filePath = filePath
    }
    
    func open() -> Bool {
        socketHandle = socket(AF_UNIX, SOCK_STREAM, 0)
        if socketHandle < 0 {
            print("❌ Socket create failed")
            return false
        }
        
        // Correctly initialize sockaddr_un for Darwin
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathStr = (filePath as NSString).utf8String
        if let pathStr = pathStr {
            let pathLen = strlen(pathStr)
            addr.sun_len = UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size + Int(pathLen) + 1)
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                strlcpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), pathStr, 104)
            }
        }
        
        let len = socklen_t(addr.sun_len)
        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketHandle, $0, len)
            }
        }
        
        if connectResult < 0 {
            print("❌ Socket connect failed: \(String(cString: strerror(errno)))")
            Darwin.close(socketHandle)
            socketHandle = -1
            return false
        }
        
        var value = 1
        setsockopt(socketHandle, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int>.size))
        
        return true
    }
    
    func close() {
        if socketHandle >= 0 {
            Darwin.close(socketHandle)
            socketHandle = -1
        }
    }
    
    func send(data: Data) -> Bool {
        return data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            return send(baseAddress: baseAddress, count: data.count)
        }
    }

    func send(baseAddress: UnsafeRawPointer, count: Int) -> Bool {
        guard socketHandle >= 0 else { return false }
        
        var sent = 0
        while sent < count {
            let result = write(socketHandle, baseAddress.advanced(by: sent), count - sent)
            if result < 0 {
                if errno == EINTR { continue }
                return false
            }
            if result == 0 { return false }
            sent += result
        }
        return true
    }
}

class SampleHandler: RPBroadcastSampleHandler {
    
    private var client: SocketConnection?
    private let appGroupIdentifier = "group.com.eastlakestudio.castnow.app"
    private var imageContext = CIContext(options: [
        CIContextOption.useSoftwareRenderer: false,
        CIContextOption.priorityRequestLow: true
    ])
    
    private var lastFrameTime: Int64 = 0
    private let frameIntervalNs: Int64 = 1_000_000_000 / 15 
    private var connectionTimer: Timer?

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("🚀 Broadcast Extension Started")
        
        let bundle = Bundle.main
        let appGroupIdentifier = bundle.object(forInfoDictionaryKey: "RTCAppGroupIdentifier") as? String ?? self.appGroupIdentifier
        
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Error: Could not verify App Group container for identifier: \(appGroupIdentifier)")
            finishBroadcastWithError(NSError(domain: "SampleHandler", code: 1, userInfo: [NSLocalizedDescriptionKey : "App Group Error: Client is not entitled for \(appGroupIdentifier). Check project settings."]))
            return
        }
        
        let socketPath = container.appendingPathComponent("rtc_SSFD").path
        client = SocketConnection(filePath: socketPath)
        
        // Retry connection as the host app might be starting the server
        var connected = false
        for i in 1...20 { // 20 attempts * 0.3s = 6 seconds
            if let client = client, client.open() {
                print("✅ Connected to flutter_webrtc socket on attempt \(i)")
                connected = true
                break
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        if !connected {
            print("❌ Failed to connect after all attempts")
            finishBroadcastWithError(NSError(domain: "SampleHandler", code: 2, userInfo: [NSLocalizedFailureReasonErrorKey : "Handshake Failed: Ensure the Main App is running and Broadcast page is open."]))
            return
        }
        
        // Start a heartbeat timer to detect if host app disconnects (e.g., user clicked explicit cancel)
        DispatchQueue.main.async {
            self.connectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkHostConnection()
            }
        }
    }
    
    private func checkHostConnection() {
        guard let socketHandle = client?.socketHandle, socketHandle >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 1)
        // MSG_PEEK | MSG_DONTWAIT allows us to check if the socket is closed without reading data
        let result = recv(socketHandle, &buffer, 1, MSG_PEEK | MSG_DONTWAIT)
        if result == 0 {
            // EOF: Host closed the connection
            print("🛑 Host closed socket connection.")
            stopGracefully()
        } else if result < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
            // Socket error
            print("🛑 Socket error detected: \(errno)")
            stopGracefully()
        }
    }
    
    private func stopGracefully() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        // Using NSLocalizedFailureReasonErrorKey to customize the system alert message
        let error = NSError(domain: "CastNow", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: "直播已由宿主应用正常结束"])
        finishBroadcastWithError(error)
    }
    
    override func broadcastFinished() {
        print("🛑 Broadcast Finished")
        connectionTimer?.invalidate()
        connectionTimer = nil
        client?.close()
        client = nil
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard let client = client, sampleBufferType == .video else { return }
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
        if currentTime - lastFrameTime < frameIntervalNs && lastFrameTime != 0 {
            return
        }
        lastFrameTime = currentTime
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        var orientation: Int = 0
        if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
            orientation = orientationAttachment.intValue
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let jpegData = imageContext.jpegRepresentation(of: ciImage, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.7]) else {
            return
        }
        
        let header = "HTTP/1.1 200 OK\r\n" +
                     "Content-Type: image/jpeg\r\n" +
                     "Buffer-Width: \(width)\r\n" +
                     "Buffer-Height: \(height)\r\n" +
                     "Buffer-Orientation: \(orientation)\r\n" +
                     "Content-Length: \(jpegData.count)\r\n\r\n"
        
        guard let headerData = header.data(using: .utf8) else { return }
        
        var frameData = Data()
        frameData.append(headerData)
        frameData.append(jpegData)
        
        let chunkSize = 10 * 1024
        var offset = 0
        while offset < frameData.count {
            let chunkLen = min(chunkSize, frameData.count - offset)
            let chunk = frameData.subdata(in: offset..<offset+chunkLen)
            if !client.send(data: chunk) {
                print("❌ Failed to send frame chunk. Host app likely disconnected.")
                stopGracefully()
                break
            }
            offset += chunkLen
        }
    }
}
