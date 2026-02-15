import Flutter
import UIKit
import ReplayKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Register channel after a small delay to ensure rootViewController is available
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if let controller = self.window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "media_projection", binaryMessenger: controller.binaryMessenger)
            channel.setMethodCallHandler({ [weak self] (call, result) in
                print("📲 Native received method call: \(call.method)")
                if call.method == "startMediaProjectionService" {
                    self?.showBroadcastPicker()
                    result(nil)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            })
            print("✅ Native MethodChannel 'media_projection' registered successfully.")
        } else {
            print("❌ Error: rootViewController is STILL not a FlutterViewController after delay.")
        }
    }
    
    return result
  }

  private func showBroadcastPicker() {
    DispatchQueue.main.async {
      if #available(iOS 12.0, *) {
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        pickerView.preferredExtension = "com.eastlakestudio.castnow.app.BroadcastExtension"
        pickerView.showsMicrophoneButton = false
        
        // Find the key window reliably
        let window = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }.first
            ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.keyWindow
        
        if let keyWindow = window {
          keyWindow.addSubview(pickerView)
          pickerView.center = keyWindow.center
          pickerView.alpha = 0.01
          
          // Small delay to ensure subviews are loaded
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              print("🔍 Searching for Broadcast Picker button...")
              var foundButton = false
              for view in pickerView.subviews {
                if let button = view as? UIButton {
                  print("✅ Found button in direct subviews, clicking...")
                  button.sendActions(for: .touchUpInside)
                  foundButton = true
                  break
                }
              }
              
              if !foundButton {
                  print("⚠️ Button not found in direct subviews, searching deeper...")
                  // Fallback: If not found, try a deeper search
                  self.searchAndClickButton(in: pickerView)
              }
              
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                  pickerView.removeFromSuperview()
              }
          }
        }
      }
    }
  }

  private func searchAndClickButton(in view: UIView) {
    for subview in view.subviews {
        if let button = subview as? UIButton {
            button.sendActions(for: .touchUpInside)
            return
        }
        searchAndClickButton(in: subview)
    }
  }
}
