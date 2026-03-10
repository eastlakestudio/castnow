// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Constants & Theme ---
const Color kBackgroundColor = Color(0xFF020617);
const Color kSurfaceColor = Color(0xFF0F172A);
const Color kPrimaryColor = Color(0xFFF59E0B);
const Color kTextPrimary = Color(0xFFF8FAFC);
const Color kTextSecondary = Color(0xFF94A3B8);

const String kProProductId = 'com.eastlakestudio.castnow.app';
const String kProVersionKey = 'is_pro_version';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CastNowApp());
}

class CastNowApp extends StatelessWidget {
  const CastNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'CastNow Native',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackgroundColor,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          surface: kSurfaceColor,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Paid App Model: Pro version check
  bool _isPro = false;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    super.initState();
    _loadProStatus();
    _initializeIAP();
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPro = prefs.getBool(kProVersionKey) ?? false;
    });
  }

  void _initializeIAP() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Handle error here
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Show error UI
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _updateProStatus(true);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<void> _updateProStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kProVersionKey, isPro);
    setState(() {
      _isPro = isPro;
    });
  }

  Future<void> _buyPro() async {
    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Store not available')),
          );
        }
        return;
      }

      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails({kProProductId});

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("Product not found: ${response.notFoundIDs}");
      }

      if (response.productDetails.isNotEmpty) {
        final productDetails = response.productDetails.first;
        final PurchaseParam purchaseParam =
            PurchaseParam(productDetails: productDetails);
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint("Purchase error: $e");
    }
  }

  void _showProDialog() async {
    String price = "---";
    try {
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails({kProProductId});
      if (response.productDetails.isNotEmpty) {
        price = response.productDetails.first.price;
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: kPrimaryColor, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                "Upgrade to Pro",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Unlock all features and enjoy seamless screen sharing experience.",
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildProFeature(Icons.timer_off_rounded, "Unlimited Casting Time"),
              _buildProFeature(Icons.bolt_rounded, "Faster Connection"),
              _buildProFeature(Icons.hd_rounded, "High Definition Quality"),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _buyPro();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Unlock for $price",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Later",
                  style: TextStyle(color: kTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content,
      {String? url}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title,
            style: const TextStyle(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child:
                Text(content, style: const TextStyle(color: kTextSecondary))),
        actions: [
          if (url != null)
            TextButton(
              onPressed: () => _launchURL(url),
              child: const Text("VIEW ON GITHUB",
                  style: TextStyle(
                      color: kPrimaryColor, fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE",
                style: TextStyle(
                    color: kPrimaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    Widget brandSection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // P2P Badge like App.vue
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text("P2P SECURE",
                  style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Logo Area
        Container(
          width: isLandscape ? 60 : 80,
          height: isLandscape ? 60 : 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF020617)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(isLandscape ? 18 : 24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                  color: kPrimaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Icon(Icons.bolt_rounded,
              color: kPrimaryColor, size: isLandscape ? 36 : 48),
        ),
        SizedBox(height: isLandscape ? 12 : 24),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'Cast'),
              TextSpan(text: 'Now', style: TextStyle(color: kPrimaryColor)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language_rounded, color: kTextSecondary, size: 14),
            const SizedBox(width: 6),
            const Text(
              "Receive on: ",
              style: TextStyle(color: kTextSecondary, fontSize: 12),
            ),
            GestureDetector(
              onTap: () => _launchURL("https://castnow.vercel.app"),
              child: Container(
                padding: const EdgeInsets.only(bottom: 2), // Spacing
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: kPrimaryColor, width: 0.8),
                  ),
                ),
                child: const Text(
                  "castnow.vercel.app",
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    Widget actionsSection = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            context,
            title: "Broadcast",
            subtitle: "Share camera or screen",
            icon: Icons.wifi_tethering,
            color: kPrimaryColor,
            textColor: Colors.black,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BroadcastScreen(isPro: _isPro))),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            context,
            title: "Receive",
            subtitle: "Watch a stream",
            icon: Icons.download_rounded,
            color: kSurfaceColor,
            textColor: kTextPrimary,
            isOutlined: true,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReceiveScreen())),
          ),
        ],
      ),
    );

    Widget footerSection = Padding(
      padding: EdgeInsets.only(top: isLandscape ? 32 : 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFooterLink(context, "SOURCE", "Source Code",
                  "The source code for CastNow is available on GitHub under the MIT license.",
                  url: "https://github.com/MinghuaLiu1977/castnow"),
              if (!isLandscape) const SizedBox(width: 32),
              if (isLandscape) const SizedBox(width: 24),
              _buildFooterLink(context, "PRIVACY", "Privacy Policy",
                  "We value your privacy. CastNow utilizes direct peer-to-peer connections. Your stream data never touches our servers. We do not collect or store any personal information."),
              if (!isLandscape) const SizedBox(width: 32),
              if (isLandscape) const SizedBox(width: 24),
              _buildFooterLink(context, "TERMS", "Terms of Service",
                  "By using CastNow, you agree that you are responsible for the content you share. The service is provided 'as is' without warranties of any kind."),
              if (isLandscape) ...[
                const SizedBox(width: 24),
                const Text(
                  "EASTLAKE STUDIO",
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ],
            ],
          ),
          if (!isLandscape) ...[
            const SizedBox(height: 16),
            const Text(
              "MADE BY EASTLAKE STUDIO",
              style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top padding to help centering
                          if (isLandscape) const SizedBox(height: 1),
                          if (!isLandscape) const SizedBox(height: 40),

                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isLandscape
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(child: brandSection),
                                        const SizedBox(width: 40),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              actionsSection,
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        brandSection,
                                        const SizedBox(height: 60),
                                        actionsSection,
                                      ],
                                    ),
                            ],
                          ),

                          footerSection,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Refined Top-Right PRO Badge / Status
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: GestureDetector(
              onTap: _isPro ? null : _showProDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _isPro
                      ? const LinearGradient(
                          colors: [Color(0xFF334155), Color(0xFF1E293B)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _isPro ? Colors.white10 : Colors.white24,
                      width: 0.5),
                  boxShadow: [
                    if (!_isPro)
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        _isPro ? Icons.verified_rounded : Icons.stars_rounded,
                        color: _isPro ? const Color(0xFF38BDF8) : Colors.black,
                        size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _isPro ? "PRO" : "GO PRO",
                      style: TextStyle(
                          color: _isPro ? Colors.white.withOpacity(0.9) : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(
      BuildContext context, String label, String title, String content,
      {String? url}) {
    return GestureDetector(
      onTap: () => _showInfoDialog(context, title, content, url: url),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required Color textColor,
      required VoidCallback onTap,
      bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: isOutlined ? Border.all(color: Colors.white12) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOutlined
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: textColor, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: textColor.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: textColor.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

// --- iOS Native Picker Widget ---
class IOSBroadcastPicker extends StatelessWidget {
  final double width;
  final double height;

  const IOSBroadcastPicker({
    super.key,
    this.width = 120,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      height: height,
      child: const UiKitView(
        viewType: 'castnow_picker_view',
        creationParams: {},
        creationParamsCodec: StandardMessageCodec(),
      ),
    );
  }
}

// --- Broadcast Screen (Sender) ---
class BroadcastScreen extends StatefulWidget {
  final bool isPro;
  const BroadcastScreen({super.key, this.isPro = false});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  Peer? _peer;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  String? _peerId;
  bool _isScreenSharing = false;
  final List<DataConnection> _connections = [];
  bool _isLoading = false;

  // Time Limit Logic
  Timer? _limitTimer;
  int _remainingSeconds = 600; // 10 minutes

  // Manual trigger via MethodChannel
  static const _pickerControlChannel = MethodChannel('castnow_picker_control');

  Future<void> _triggerPicker() async {
    try {
      if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        if (!iosInfo.isPhysicalDevice) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("⚠️ 模拟器限制"),
                content: const Text(
                    "你当前正在使用 iOS 模拟器。\n\n苹果系统规定：模拟器不支持 ReplayKit 录屏功能，点击不会弹出菜单。\n\n请切换到【真机】进行测试。"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("确认"))
                ],
              ),
            );
          }
          return;
        }
      }

      debugPrint("📢 Manually triggering broadcast picker via native...");
      final bool? success =
          await _pickerControlChannel.invokeMethod<bool>('triggerPicker');
      debugPrint("✅ Trigger success: $success");
    } catch (e) {
      debugPrint("❌ Error triggering picker: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _initRenderer();
    WakelockPlus.enable();

    // Listen for logs from native code
    _pickerControlChannel.setMethodCallHandler((call) async {
      if (call.method == "nativeLog") {
        debugPrint("🍎 NATIVE: ${call.arguments}");
      }
    });
  }

  Future<void> _initRenderer() async {
    await _localRenderer.initialize();

    // Listen for native stop signal (from notification)
    // Listen for native stop signal (from notification)
    if (Platform.isAndroid) {
      const channel = MethodChannel('media_projection');
      channel.setMethodCallHandler((call) async {
        debugPrint("📢 Received MethodChannel call: ${call.method}");
        if (call.method == "onStopPressed") {
          debugPrint("🛑 Native STOP signal received. Navigating back.");
          _stopBroadcast();
        }
      });
    }

    if (mounted) setState(() {});
  }

  bool _isStopping = false;

  void _stopBroadcast() {
    if (!mounted || _isStopping) return;
    _isStopping = true;

    // 1. Close Peer & Connections
    _peer?.dispose();
    _peer = null;

    // 2. Stop Service (Native notification)
    // 2. Stop Service (Native notification)
    if (Platform.isAndroid) {
      const MethodChannel('media_projection')
          .invokeMethod('stopMediaProjectionService');
    }

    // 3. Cleanup local state
    _localStream?.dispose();
    _localStream = null;
    _localRenderer.srcObject = null;

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Optional: Reset state if not popped (shouldn't happen if pushed correctly)
      setState(() {
        _peerId = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _startBroadcast(bool isScreen) async {
    setState(() => _isLoading = true);
    try {
      // 1. Generate 6-digit access key
      final code = (100000 + math.Random().nextInt(900000)).toString();

      // 2. Acquire media stream FIRST
      Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': isScreen
            ? true
            : {'facingMode': 'user', 'width': 1280, 'height': 720}
      };

      if (isScreen) {
        // 跨平台屏幕共享逻辑
        if (kIsWeb ||
            Platform.isAndroid ||
            Platform.isMacOS ||
            Platform.isWindows) {
          if (Platform.isAndroid) {
            // 1. 检查当前状态
            var status = await Permission.notification.status;

            if (status.isDenied) {
              status = await Permission.notification.request();
              // 🛑 CRITICAL FIX: After system permission dialog closes, Activity might be in proper resume cycle.
              // Starting Foreground Service immediately can crash (Background Service Start Restriction).
              // Wait for 1s to ensure App is recognized as "Foreground" and permission is synced.
              if (status.isGranted) {
                debugPrint(
                    "✅ Notification permission granted. Waiting for system sync...");
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }

            // 🛑 核心拦截点 🛑
            // 如果此时还是没授权（可能是用户拒绝，也可能是 manifest 缓存问题）
            if (!status.isGranted) {
              debugPrint("❌ 致命错误：没有通知权限，前台服务无法启动！");

              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("权限缺失"),
                    content: const Text(
                        "检测到通知权限缺失。\n\nAndroid 系统要求：开启录屏必须先授予通知权限。\n\n请检查：\n1. 是否已卸载重装 App？\n2. 请去设置中手动开启权限。"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          openAppSettings(); // 引导去设置
                        },
                        child: const Text("去设置"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("取消"),
                      ),
                    ],
                  ),
                );
              }
              // ⛔️ 绝对不能继续，否则必崩 ⛔️
              setState(() => _isLoading = false);
              return;
            }
          }
          const channel = MethodChannel('castnow_picker');

          // 1. Start Media Projection Service
          // The native code will handle the Android 14 bridge/polling automatically.
          debugPrint("🚀 Starting media projection service...");
          await channel.invokeMethod('startMediaProjectionService', {
            'type': 'mediaProjection',
            'code': code,
          });

          //await Future.delayed(const Duration(milliseconds: 1500));

          // 2. Request Screen Capture (Plugin's native prompt)
          debugPrint("📸 Requesting screen capture permission...");
          _localStream =
              await navigator.mediaDevices.getDisplayMedia({'audio': false});
          debugPrint("✅ Screen capture stream acquired successfully.");

          // 3. Listen for "Stop" from System UI
          // When user clicks "Stop sharing" in notification panel, this fires.
          var videoTrack = _localStream!.getVideoTracks()[0];
          videoTrack.onEnded = () {
            debugPrint("📷 MEDIA TRACK ENDED: System 'Stop' button clicked.");
            _stopBroadcast();
          };

          videoTrack.onMute = () {
            debugPrint(
                "🔇 MEDIA TRACK MUTED: Stream paused or stopped sending frames.");
            // Optional: If muted for extensive time, could treat as stop.
          };

          // 4. Listen for track removal (common in some implementations)
          _localStream!.onRemoveTrack = (track) {
            debugPrint("👋 TRACK REMOVED from stream. Triggering termination.");
            _stopBroadcast();
          };

          // --- Session Lifecycle: Detect system stop ---
          for (var track in _localStream!.getTracks()) {
            track.onEnded = () {
              debugPrint(
                  "🎥 [${track.kind}] system signal: track.onEnded triggered.");
              _stopBroadcast();
            };
          }
        } else if (Platform.isIOS) {
          // 0. Environment check
          final deviceInfo = DeviceInfoPlugin();
          final iosInfo = await deviceInfo.iosInfo;
          if (!iosInfo.isPhysicalDevice) {
            debugPrint("❌ Environment Error: Simulator detected.");
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("iOS 模拟器不支持录屏，请使用真机")));
            setState(() => _isLoading = false);
            return;
          }

          // 1. First, Request Microphone permission
          debugPrint("🎤 Step 1: Requesting Microphone permission...");
          await Permission.microphone.request();

          // 2. Second, Request Screen Capture via getDisplayMedia
          // This starts the socket server in the helper extension architecture.
          debugPrint(
              "📸 Step 2: Starting socket server (deviceId: broadcast)...");
          _localStream = await navigator.mediaDevices.getDisplayMedia({
            'video': {
              'deviceId': 'broadcast',
            },
            'audio': false
          });
          debugPrint(
              "✅ iOS Screen Capture stream prepared. Stream ID: ${_localStream?.id}");

          // 3. Signal user to pick
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("服务已就绪，请点击下方按钮启动录屏")));

          setState(() => _isLoading = false);
        }
      } else {
        // Camera source
        if (!kIsWeb) {
          await Permission.camera.request();
          await Permission.microphone.request();
        }
        _localStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
      }

      _localRenderer.srcObject = _localStream;
      _isScreenSharing = isScreen;

      // 3. Initialize Peer AFTER stream is acquired
      final peer = Peer(id: code, options: PeerOptions(debug: LogLevel.All));
      _peer = peer;

      // 3. Setup signaling
      peer.on("open").listen((id) {
        if (!mounted) return;
        setState(() {
          _peerId = id;
          _isLoading = false;
        });
      });

      _peer!.on("connection").listen((conn) {
        _connections.add(conn);
        // Auto-minimize app after receiver connects (Android Screen Share only)
        if (_isScreenSharing && !kIsWeb && Platform.isAndroid) {
          const channel0 = MethodChannel('media_projection');
          channel0.invokeMethod('minimizeApp');
        }

        // Active call to receiver
        if (_localStream != null) {
          _peer!.call(conn.peer, _localStream!);
        }
      });

      // Start timer if not PRO
      if (!widget.isPro) {
        _remainingSeconds = 600;
        _limitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            } else {
              timer.cancel();
              _showTimeUpDialog();
            }
          });
        });
      }

      setState(() {});
    } catch (e) {
      debugPrint("Error starting broadcast: $e");

      // Attempt to clean up native service if it was started
      try {
        if (Platform.isAndroid) {
          const channel = MethodChannel('castnow_picker');
          await channel.invokeMethod('stopMediaProjectionService');
        }
      } catch (_) {}

      if (mounted) {
        // Reset state so we stay on the selection screen
        setState(() {
          _isLoading = false;
          _peerId = null;
          _peer = null;
        });

        // Only show error if it's not a user cancellation
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('cancel') &&
            !errorStr.contains('denied') &&
            !errorStr.contains('user_rejected') &&
            !errorStr.contains('give permission')) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        } else {
          debugPrint(
              "User cancelled or denied permission. Returning to selection.");
        }
      }
    }
  }

  void _switchCamera() async {
    if (_localStream != null && !_isScreenSharing) {
      final tracks = _localStream!.getVideoTracks();
      if (tracks.isNotEmpty) {
        await Helper.switchCamera(tracks.first);
      } else {
        debugPrint("❌ No video tracks found to switch.");
      }
    }
  }

  void _showTimeUpDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Time Limit Reached"),
        content: const Text(
            "Free version is limited to 10 minutes per session.\n\nPlease upgrade to PRO for unlimited casting."),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _stopBroadcast();
              },
              child: const Text("CLOSE"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint("🧹 Disposing BroadcastScreenState");
    _limitTimer?.cancel();
    _stopBroadcast();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (_peerId == null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Choose Source"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                isLandscape
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                              child: _buildSourceBtn(
                                  Icons.phone_android,
                                  "Screen Share",
                                  () => _startBroadcast(true),
                                  isLandscape)),
                          const SizedBox(width: 24),
                          Expanded(
                              child: _buildSourceBtn(Icons.camera_alt, "Camera",
                                  () => _startBroadcast(false), isLandscape)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSourceBtn(Icons.phone_android, "Screen Share",
                              () => _startBroadcast(true), isLandscape),
                          const SizedBox(height: 20),
                          _buildSourceBtn(Icons.camera_alt, "Camera",
                              () => _startBroadcast(false), isLandscape),
                        ],
                      ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [
                              Icon(Icons.circle,
                                  color: _isScreenSharing
                                      ? Colors.blue
                                      : Colors.red,
                                  size: 12),
                              const SizedBox(width: 8),
                              Text(
                                  _isScreenSharing
                                      ? "SHARING SCREEN"
                                      : "ON AIR",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              if (!widget.isPro) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ]),
                          ),
                          IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.close, color: Colors.white))
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Constrained Video Preview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isLandscape ? 400 : double.infinity,
                          maxHeight: isLandscape ? 200 : 300,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _localStream != null
                                ? RTCVideoView(_localRenderer,
                                    mirror: !_isScreenSharing,
                                    objectFit: RTCVideoViewObjectFit
                                        .RTCVideoViewObjectFitContain)
                                : Container(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Code Display
                    if (_peerId != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: kSurfaceColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("SHARING ACCESS KEY",
                                style: TextStyle(
                                    color: kTextSecondary,
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                                children: [
                                  TextSpan(text: "Browser receiver: "),
                                  TextSpan(
                                    text: "castnow.vercel.app",
                                    style: TextStyle(
                                        color: kPrimaryColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _peerId!
                                  .split('')
                                  .map((char) => Container(
                                        width: 36,
                                        height: 48,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: kPrimaryColor
                                                    .withOpacity(0.5))),
                                        child: Text(char,
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: kPrimaryColor)),
                                      ))
                                  .toList(),
                            ),
                            if (_isScreenSharing && Platform.isIOS) ...[
                              const SizedBox(height: 16),
                              // 1. The visible but possibly non-clickable native icon (for system linkage)
                              const IOSBroadcastPicker(
                                width: 80,
                                height: 80,
                              ),
                              const SizedBox(height: 12),
                              // 2. The large, reliable Flutter button as requested by user
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _triggerPicker,
                                  icon: const Icon(Icons.touch_app_rounded,
                                      color: Colors.white),
                                  label: const Text("TAP TO START BROADCAST",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(
                                            color: Colors.white24)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "If popup doesn't appear, ensure Screen Recording is allowed in Settings",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 10),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (!_isScreenSharing)
                              TextButton.icon(
                                onPressed: _switchCamera,
                                icon: const Icon(Icons.flip_camera_ios,
                                    color: Colors.white),
                                label: const Text("Switch Camera",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _stopBroadcast,
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white54),
                                label: const Text("CANCEL / TERMINATE",
                                    style: TextStyle(color: Colors.white54)),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                  color: Colors.black87,
                  child: const Center(
                      child: CircularProgressIndicator(color: kPrimaryColor))),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBtn(
      IconData icon, String label, VoidCallback onTap, bool isLandscape) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: isLandscape ? null : 280,
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.all(isLandscape ? 32 : 40),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isLandscape ? 48 : 56, color: kPrimaryColor),
            const SizedBox(height: 16),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ],
        ),
      ),
    );
  }
}

// --- Receive Screen (Viewer) ---
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final TextEditingController _codeController = TextEditingController();
  Peer? _peer;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peer?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // Receiver also requires ICE configuration for successful P2P traversal
  Map<String, dynamic> _getIceServerConfig() {
    return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun.cloudflare.com:3478'},
        {'urls': 'stun:stun.miwifi.com:3478'},
        {'urls': 'stun:stun.cdn.aliyun.com:3478'},
      ]
    };
  }

  void _joinStream() {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() => _isConnecting = true);

    final peer = Peer(
        options:
            PeerOptions(debug: LogLevel.All, config: _getIceServerConfig()));
    _peer = peer;

    peer.on("open").listen((id) {
      final conn = peer.connect(code);

      conn.on("open").listen((_) {
        debugPrint("Connected to broadcaster signaling");
      });

      conn.on("close").listen((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Broadcast ended")));
          Navigator.pop(context);
        }
      });
    });

    peer.on("call").listen((mediaConnection) async {
      debugPrint("Received call from ${mediaConnection.peer}");

      // --- WebRTC Debug Logs ---
      mediaConnection.peerConnection?.onIceConnectionState =
          (RTCIceConnectionState state) {
        debugPrint("🔥 [手机端 ICE 状态]: ${state.toString()}");
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint("❌ 警告：打洞失败，请检查代理设置或 STUN/TURN 服务器");
        }
      };

      mediaConnection.peerConnection?.onIceCandidate =
          (RTCIceCandidate candidate) {
        debugPrint("🏠 [手机端候选地址]: ${candidate.candidate}");
      };

      // Answer the call. peerdart explicitly requires a non-null MediaStream.
      // We create a dummy stream for "receive-only" mode.
      // Note: This might ask for microphone permission if we ask for audio.
      // We try to ask for nothing if possible, but WebRTC usually demands at least one track.
      // Let's try audio only as it is less intrusive than camera.
      MediaStream dummyStream;
      try {
        dummyStream = await navigator.mediaDevices
            .getUserMedia({'audio': true, 'video': false});
      } catch (e) {
        debugPrint("Error creating dummy stream: $e");
        return;
      }

      mediaConnection.answer(dummyStream);
      mediaConnection.on("stream").listen((stream) {
        debugPrint("Received remote stream: ${stream.id}");
        debugPrint("Video tracks: ${stream.getVideoTracks().length}");
        if (stream.getVideoTracks().isNotEmpty) {
          debugPrint(
              "Video track enabled: ${stream.getVideoTracks().first.enabled}");
        }

        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _isConnecting = false;
        });
      });

      mediaConnection.on("close").listen((_) {
        debugPrint("Media connection closed");
        setState(() {
          _isConnected = false;
          _remoteRenderer.srcObject = null;
        });
      });

      mediaConnection.on("error").listen((e) {
        debugPrint("Media connection error: $e");
      });
    });

    peer.on("error").listen((err) {
      debugPrint("Peer Error: $err");
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Connection Failed. Check code.")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            RTCVideoView(_remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                  ),
                ),
              ),
            )
          ],
        ),
      );
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Join Stream"),
          backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    const Text("ENTER ACCESS KEY",
                        style: TextStyle(
                            color: kTextSecondary,
                            letterSpacing: 3,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: TextField(
                        controller: _codeController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: TextStyle(
                            fontSize: isLandscape ? 32 : 48,
                            fontWeight: FontWeight.w900,
                            color: kPrimaryColor,
                            letterSpacing: isLandscape ? 4 : 8),
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: kSurfaceColor,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: isLandscape ? 12 : 24),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                          hintText: "000000",
                          hintStyle:
                              TextStyle(color: kSurfaceColor.withBlue(40)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isConnecting ? null : _joinStream,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          child: _isConnecting
                              ? const CircularProgressIndicator(
                                  color: Colors.black)
                              : const Text("CONNECT NOW",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
