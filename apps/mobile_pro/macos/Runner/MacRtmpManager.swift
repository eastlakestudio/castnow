import Cocoa
import FlutterMacOS
import HaishinKit
import AVFoundation

public class MacRtmpManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public static let shared = MacRtmpManager()
    
    private var rtmpConnection: RTMPConnection?
    private var rtmpStream: RTMPStream?
    
    private var captureSession: AVCaptureSession?
    private var isStreaming = false

    public func startBroadcast(url: String, key: String) {
        if isStreaming { return }
        isStreaming = true
        
        print("🚀 [MacRtmpManager] Starting RTMP Broadcast to \(url)")
        
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection!)
        
        setupCaptureSession()
        
        rtmpConnection?.connect(url)
        rtmpStream?.publish(key)
    }
    
    public func stopBroadcast() {
        if !isStreaming { return }
        isStreaming = false
        
        print("🛑 [MacRtmpManager] Stopping RTMP Broadcast")
        
        captureSession?.stopRunning()
        captureSession = nil
        
        rtmpStream?.close()
        rtmpConnection?.close()
        rtmpStream = nil
        rtmpConnection = nil
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // 1. Screen Input
        let displayId = CGMainDisplayID()
        if let screenInput = AVCaptureScreenInput(displayID: displayId) {
            screenInput.minFrameDuration = CMTimeMake(value: 1, timescale: 30) // 30 FPS
            screenInput.capturesCursor = true
            screenInput.capturesMouseClicks = true
            if session.canAddInput(screenInput) {
                session.addInput(screenInput)
            }
        }
        
        // 2. Audio Input (Microphone)
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            if let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
        }
        
        // 3. Video Output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let videoQueue = DispatchQueue(label: "com.eastlakestudio.castnow.videoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        // 4. Audio Output
        let audioOutput = AVCaptureAudioDataOutput()
        let audioQueue = DispatchQueue(label: "com.eastlakestudio.castnow.audioQueue")
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
        
        session.startRunning()
        self.captureSession = session
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isStreaming, let stream = rtmpStream else { return }
        
        if output is AVCaptureVideoDataOutput {
            stream.append(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            stream.append(sampleBuffer)
        }
    }
}
