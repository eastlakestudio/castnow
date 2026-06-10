import Cocoa
import FlutterMacOS
import VideoToolbox

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let rtmpChannel = FlutterMethodChannel(name: "com.eastlakestudio.castnow.pro/rtmp_macos",
                                              binaryMessenger: controller.engine.binaryMessenger)
    rtmpChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "startRtmpBroadcast" {
        guard let args = call.arguments as? [String: Any],
              let url = args["url"] as? String,
              let key = args["key"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing URL or Key", details: nil))
          return
        }
        MacRtmpManager.shared.startBroadcast(url: url, key: key)
        result(true)
      } else if call.method == "stopRtmpBroadcast" {
        MacRtmpManager.shared.stopBroadcast()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

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
        
        rtmpStream?.videoSettings.videoSize = CGSize(width: 1920, height: 1080)
        rtmpStream?.videoSettings.bitRate = 4_000_000 // 4 Mbps
        rtmpStream?.videoSettings.profileLevel = kVTProfileLevel_H264_High_AutoLevel as String
        
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
