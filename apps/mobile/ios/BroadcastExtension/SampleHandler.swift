//
//  SampleHandler.swift
//  BroadcastExtension
//
//  Created by Minghua LIu on 2026/1/22.
//

import ReplayKit
import Foundation

// MARK: - SocketConnection
class SocketConnection {
    var filePath: String?
    var socketHandle: Int32 = -1
    
    init(filePath: String) {
        self.filePath = filePath
    }
    
    func open() -> Bool {
        guard let filePath = filePath else { return false }
        
        socketHandle = socket(AF_UNIX, SOCK_STREAM, 0)
        if socketHandle < 0 {
            print("❌ Socket create failed")
            return false
        }
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        // Remove existing file if needed (client shouldn't remove, but good to know path nuances)
        // Here we just connect
        let pathLen = filePath.utf8.count
        if pathLen >= 104 { // UNIX_PATH_MAX
             print("❌ Socket path too long")
             return false
        }
        
        let pathStr = (filePath as NSString).utf8String
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            // Bind path safely
            strlcpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), pathStr, 104)
        }
        
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        // We need to cast to generic sockaddr
        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketHandle, $0, len)
            }
        }
        
        if connectResult < 0 {
            print("❌ Socket connect failed: \(String(cString: strerror(errno)))")
            return false
        }
        
        // Set SIGPIPE to ignore so we don't crash on broken pipe
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
        guard socketHandle >= 0 else { return false }
        
        return data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            
            var sent = 0
            while sent < data.count {
                let result = write(socketHandle, baseAddress.advanced(by: sent), data.count - sent)
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
}

// MARK: - SampleHandler

class SampleHandler: RPBroadcastSampleHandler {
    
    private var client: SocketConnection?
    private var frameCount = 0
    
    // IMPORTANT: This must match the App Group ID configured in Xcode
    private let appGroupIdentifier = "group.com.eastlakestudio.castnow.app" // Replace if different
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // Path to the socket used by flutter_webrtc
        // Usually it's in the App Group shared container
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Error: Could not verify App Group container. Check App Group ID.")
            // We might try a fallback or just fail gracefully
            return
        }
        
        let socketPath = container.appendingPathComponent("rtc_broadcast.socket").path
        
        client = SocketConnection(filePath: socketPath)
        if let client = client, client.open() {
            print("✅ Connected to broadcast socket")
        } else {
            print("❌ Failed to connect to broadcast socket")
            // Retry logic could go here
        }
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        client?.close()
        client = nil
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard let client = client else { return }
        
        switch sampleBufferType {
        case RPSampleBufferType.video:
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Lock the buffer
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
            
            // Get basic info
            let width = UInt32(CVPixelBufferGetWidth(imageBuffer))
            let height = UInt32(CVPixelBufferGetHeight(imageBuffer))
            let bytesPerRow = UInt32(CVPixelBufferGetBytesPerRow(imageBuffer))
            
            // Should be kCVPixelFormatType_32BGRA or 420YpCbCr8BiPlanarVideoRange
            // We assume the receiver handles raw bytes or we might need to convert.
            // For simplicity in this raw socket, we break it down.
            // Protocol:
            // [Total Size (4 bytes)] [Width (4)] [Height (4)] [Orientation (4)] [Data...]
            // Check orientation
            var orientation: UInt32 = 0
            if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
                orientation = UInt32(orientationAttachment.intValue)
            }
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
            // Calculate total size: valid data size (height * bytesPerRow)
            let dataLen = Int(height * bytesPerRow)
            let totalLen = UInt32(4 + 4 + 4 + 4 + dataLen)
            
            // Prepare Header
            var header = Data(count: 16)
            header.withUnsafeMutableBytes { ptr in
                ptr.storeBytes(of: totalLen.bigEndian, toByteOffset: 0, as: UInt32.self)
                ptr.storeBytes(of: width.bigEndian, toByteOffset: 4, as: UInt32.self)
                ptr.storeBytes(of: height.bigEndian, toByteOffset: 8, as: UInt32.self)
                ptr.storeBytes(of: orientation.bigEndian, toByteOffset: 12, as: UInt32.self)
            }
            
            // Send Header
            if !client.send(data: header) {
                print("❌ Failed to send header")
                // Reconnect?
                return
            }
            
            // Send Body
            let body = Data(bytes: baseAddress, count: dataLen)
            if !client.send(data: body) {
                print("❌ Failed to send body")
                return
            }
            
        case RPSampleBufferType.audioApp:
            break
        case RPSampleBufferType.audioMic:
            break
        @unknown default:
            break
        }
    }
}
