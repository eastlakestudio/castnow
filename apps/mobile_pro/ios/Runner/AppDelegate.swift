import Flutter
import UIKit
import ReplayKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    initAudioSession()
    
    // 在主引擎初始化时注册自定义逻辑
    if let registrar = self.registrar(forPlugin: "CastNowPickerPlugin") {
        let factory = BroadcastPickerFactory()
        registrar.register(factory, withId: "castnow_picker_view")
        
        let triggerChannel = FlutterMethodChannel(name: "castnow_picker_control", binaryMessenger: registrar.messenger())
        BroadcastPickerManager.shared.channel = triggerChannel
        triggerChannel.setMethodCallHandler { (call, result) in
            if call.method == "triggerPicker" {
                BroadcastPickerManager.shared.trigger()
                result(true)
            } else if call.method == "hidePicker" {
                BroadcastPickerManager.shared.hidePicker()
                result(true)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func initAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
      try session.setActive(true)
      print("✅ [CASTNOW] AVAudioSession initialized successfully.")
    } catch {
      print("❌ [CASTNOW] Failed to set AVAudioSession category: \(error)")
    }
  }


  // --- Background Task Management for persistence during lock ---
  private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

  override func applicationDidEnterBackground(_ application: UIApplication) {
    backgroundTaskIdentifier = application.beginBackgroundTask(withName: "CastNowPersistence") { [weak self] in
        guard let self = self else { return }
        application.endBackgroundTask(self.backgroundTaskIdentifier)
        self.backgroundTaskIdentifier = .invalid
    }
    print("🌙 [CASTNOW] App entered background, started task: \(backgroundTaskIdentifier)")
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    if backgroundTaskIdentifier != .invalid {
        print("☀️ [CASTNOW] App returning to foreground, ending task: \(backgroundTaskIdentifier)")
        application.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }
  }

  override func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
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
    
    func hidePicker() {
        log("🙈 Attempting to hide picker popup...")
        DispatchQueue.main.async {
            var foundPresentedVC = false
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    if let rootVC = window.rootViewController {
                        var topVC = rootVC
                        while let presentedVC = topVC.presentedViewController {
                            topVC = presentedVC
                        }
                        if topVC != rootVC {
                            self.log("📢 Dismissing top ViewController on window: \(type(of: topVC))")
                            topVC.dismiss(animated: true, completion: nil)
                            foundPresentedVC = true
                        }
                    }
                }
            }
            if !foundPresentedVC {
                self.log("⚠️ No presented ViewController found across any window to dismiss.")
            } else {
                self.log("✅ Picker dismissed successfully.")
            }
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
        pickerView.preferredExtension = "com.eastlakestudio.castnow.pro.BroadcastExtension"
        pickerView.showsMicrophoneButton = true
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
