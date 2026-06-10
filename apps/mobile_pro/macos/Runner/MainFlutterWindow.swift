import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let rtmpChannel = FlutterMethodChannel(name: "com.eastlakestudio.castnow.pro/rtmp_macos",
                                              binaryMessenger: flutterViewController.engine.binaryMessenger)
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

    super.awakeFromNib()
  }
}
