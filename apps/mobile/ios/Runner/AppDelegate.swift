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
    
    // 1. Register PlatformView & MethodChannel
    if let registrar = self.registrar(forPlugin: "CastNowPickerPlugin") {
      let factory = BroadcastPickerFactory()
      registrar.register(factory, withId: "castnow_picker_view")
      
      // 2. Register MethodChannel to trigger the picker manually
      let triggerChannel = FlutterMethodChannel(name: "castnow_picker_control", binaryMessenger: registrar.messenger())
      BroadcastPickerManager.shared.channel = triggerChannel
      
      triggerChannel.setMethodCallHandler { (call, result) in
          if call.method == "triggerPicker" {
              BroadcastPickerManager.shared.trigger()
              result(true)
          } else {
              result(FlutterMethodNotImplemented)
          }
      }
      print("✅ [CASTNOW] PlatformView and ControlChannel registered.")
      BroadcastPickerManager.shared.log("✅ Native logic initialized")
    } else {
      print("❌ [CASTNOW] Failed to get registrar for CastNowPickerPlugin")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Global manager to hold and trigger the picker
class BroadcastPickerManager {
    static let shared = BroadcastPickerManager()
    weak var currentPicker: RPSystemBroadcastPickerView?
    var channel: FlutterMethodChannel?
    
    func log(_ message: String) {
        // Use print for debugger console, avoid NSLog to bypass hook conflicts
        print("[BroadcastPickerManager] \(message)")
        DispatchQueue.main.async {
            self.channel?.invokeMethod("nativeLog", arguments: message)
        }
    }
    func trigger() {
        guard let picker = currentPicker else {
            log("❌ Trigger failed: picker is nil")
            return
        }
        
        // Find the UIButton inside the picker hierarchy
        func findButton(in view: UIView) -> UIButton? {
            if let button = view as? UIButton { return button }
            for subview in view.subviews {
                if let found = findButton(in: subview) { return found }
            }
            return nil
        }

        if let button = findButton(in: picker) {
            log("📢 Clicking native broadcast button...")
            // Avoid complicated string interpolation of the button itself
            button.sendActions(for: .touchUpInside)
            log("✅ Trigger sent")
        } else {
            log("❌ UI Matcher failed")
        }
    }
}

// --- PlatformView Implementation ---

class BroadcastPickerFactory: NSObject, FlutterPlatformViewFactory {
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return BroadcastPickerView(frame: frame)
    }
}

class BroadcastPickerView: NSObject, FlutterPlatformView {
    private var _container: PickerWrapperView

    init(frame: CGRect) {
        let pickerView = RPSystemBroadcastPickerView(frame: frame)
        pickerView.preferredExtension = "com.eastlakestudio.castnow.app.BroadcastExtension"
        pickerView.showsMicrophoneButton = false
        pickerView.backgroundColor = .clear
        
        BroadcastPickerManager.shared.currentPicker = pickerView
        
        _container = PickerWrapperView(picker: pickerView)
        super.init()
    }

    func view() -> UIView {
        return _container
    }
}

class PickerWrapperView: UIView {
    private let picker: RPSystemBroadcastPickerView
    
    init(picker: RPSystemBroadcastPickerView) {
        self.picker = picker
        super.init(frame: .zero)
        
        addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: topAnchor),
            picker.bottomAnchor.constraint(equalTo: bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // Clean UI for real device testing
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
