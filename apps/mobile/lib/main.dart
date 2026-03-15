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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- Constants & Theme ---
const Color kBackgroundColor = Color(0xFF020617);
const Color kSurfaceColor = Color(0xFF0F172A);
const Color kPrimaryColor = Color(0xFFF59E0B);
const Color kTextPrimary = Color(0xFFF8FAFC);
const Color kTextSecondary = Color(0xFF94A3B8);

const String kProVersionKey = 'is_pro_version';
const String kGumroadLicenseKey = 'gumroad_license_key';
const String kGumroadProductPermalink = 'ihhtg';

class GumroadService {
  static Future<bool> verifyLicense(String licenseKey, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.post(
        Uri.parse('https://api.gumroad.com/v2/licenses/verify'),
        body: {
          'product_permalink': kGumroadProductPermalink,
          'license_key': licenseKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true &&
            data['purchase'] != null &&
            data['purchase']['refunded'] != true &&
            data['purchase']['chargebacked'] != true;
      }
      return false;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

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
  final TextEditingController _licenseController = TextEditingController();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadProStatus();
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPro = prefs.getBool(kProVersionKey) ?? false;
    });
    
    // Check if we have a stored license key to verify on startup
    final storedLicense = prefs.getString(kGumroadLicenseKey);
    if (storedLicense != null && storedLicense.isNotEmpty) {
      _verifyGumroadLicense(storedLicense, silent: true);
    }
  }

  Future<void> _verifyGumroadLicense(String licenseKey, {bool silent = false}) async {
    if (!silent) {
      setState(() => _isVerifying = true);
    }

    try {
      final isValid = await GumroadService.verifyLicense(licenseKey);

      if (isValid) {
        await _updateProStatus(true, licenseKey: licenseKey);
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PRO Activated Successfully!')),
          );
        }
      } else {
        if (!silent) {
          _showErrorDialog("Invalid or inactive license key.");
          await _updateProStatus(false);
        } else {
          if (_isPro) {
            await _updateProStatus(false);
          }
        }
      }
    } catch (e) {
      debugPrint("Verification error: $e");
      if (!silent) {
        _showErrorDialog("Connection error. Please try again later.");
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _updateProStatus(bool isPro, {String? licenseKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kProVersionKey, isPro);
    if (isPro && licenseKey != null) {
      await prefs.setString(kGumroadLicenseKey, licenseKey);
    } else if (!isPro) {
      await prefs.remove(kGumroadLicenseKey);
    }
    
    if (mounted) {
      setState(() {
        _isPro = isPro;
      });
    }
  }

  void _showProDialog() async {
    if (!mounted) return;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(isLandscape ? 16 : 24),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isLandscape ? 12 : 16),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: kPrimaryColor, size: isLandscape ? 32 : 40),
                  ),
                  SizedBox(height: isLandscape ? 12 : 20),
                  const Text(
                    "Upgrade to Pro",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 8 : 12),
                  const Text(
                    "Unlock all features for life with a one-time purchase on Gumroad.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                  SizedBox(height: isLandscape ? 16 : 20),
                  
                  // License Input
                  TextField(
                    controller: _licenseController,
                    decoration: InputDecoration(
                      hintText: "Enter License Key",
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : () async {
                        final key = _licenseController.text.trim();
                        if (key.isEmpty) return;
                        setDialogState(() => _isVerifying = true);
                        await _verifyGumroadLicense(key);
                        if (mounted) {
                          setDialogState(() => _isVerifying = false);
                          if (_isPro) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isVerifying 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text("ACTIVATE PRO", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  SizedBox(height: isLandscape ? 16 : 20),
                  const Divider(color: Colors.white10),
                  SizedBox(height: isLandscape ? 16 : 20),
                  
                  _buildProFeature(Icons.timer_off_rounded, "Unlimited Casting Time", isLandscape),
                  _buildProFeature(Icons.bolt_rounded, "Faster Connection", isLandscape),
                  _buildProFeature(Icons.hd_rounded, "High Definition Quality", isLandscape),
                  
                  SizedBox(height: isLandscape ? 20 : 28),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _launchURL("https://gumroad.com/l/$kGumroadProductPermalink"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("BUY ON GUMROAD (\$5.99)", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  if (!isLandscape)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("LATER", style: TextStyle(color: kTextSecondary)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProFeature(IconData icon, String text, [bool isLandscape = false]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLandscape ? 4 : 8),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: isLandscape ? 18 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: isLandscape ? 13 : 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _licenseController.dispose();
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

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                "Purchase Error",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 14,
                  height: 1.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 12),
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
        SizedBox(height: isLandscape ? 8 : 20),
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
            left: 20,
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
  bool _isMuted = false;
  bool _isLoading = false;

  // Time Limit Logic
  Timer? _limitTimer;
  int _remainingSeconds = 180; // 3 minutes


  @override
  void initState() {
    super.initState();
    _initRenderer();
    WakelockPlus.enable();
  }

  Future<void> _initRenderer() async {
    await _localRenderer.initialize();

    // Listen for native stop signal (from notification)
    // Listen for native stop signal (from notification)
    if (Platform.isAndroid) {
      const channel = MethodChannel('castnow_picker');
      channel.setMethodCallHandler((call) async {
        if (kDebugMode) {
          debugPrint("📱 MethodChannel Info: ${call.method}");
        }
        if (call.method == "onStopPressed") {
          debugPrint("🛑 Native STOP signal received. Navigating back.");
          _stopBroadcast();
        }
      });
    }

    if (mounted) setState(() {});
  }

  // Shared ICE configuration for P2P traversal
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

  bool _isStopping = false;

  void _toggleMute() {
    if (_localStream == null) return;
    setState(() {
      _isMuted = !_isMuted;
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    });
  }

  Future<void> _handleExit() async {
    await _stopBroadcast();
  }

  Future<void> _stopBroadcast() async {
    if (!mounted) return;
    if (!_isStopping) {
      setState(() => _isStopping = true);
    }

    // 1. Close Peer & Connections (This triggers native socket closure immediately)
    _peer?.dispose();
    _peer = null;

    // 2. Stop Service (Native notification)
    if (Platform.isAndroid) {
      const MethodChannel('castnow_picker')
          .invokeMethod('stopMediaProjectionService');
    }

    // 3. Cleanup local state
    _localStream?.dispose();
    _localStream = null;
    _localRenderer.srcObject = null;

    // 4. Wait for iOS system popup to appear within this context before popping Nav
    if (_isScreenSharing && Platform.isIOS) {
      // User requested 4.5s delay to ensure the system popup is masked while on this screen
      await Future.delayed(const Duration(milliseconds: 4500));
    }

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
                if (kDebugMode) debugPrint(
                    "✅ Notification permission granted. Waiting for system sync...");
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }

            // 🛑 核心拦截点 🛑
            // 如果此时还是没授权（可能是用户拒绝，也可能是 manifest 缓存问题）
            if (!status.isGranted) {
              if (kDebugMode) debugPrint("❌ 致命错误：没有通知权限，前台服务无法启动！");

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
          if (kDebugMode) debugPrint("🚀 Starting media projection service...");
          await channel.invokeMethod('startMediaProjectionService', {
            'type': 'mediaProjection',
            'code': code,
          });

          //await Future.delayed(const Duration(milliseconds: 1500));

          // 2. Request Screen Capture (Plugin's native prompt)
          if (kDebugMode) debugPrint("📸 Requesting screen capture permission...");
          _localStream =
              await navigator.mediaDevices.getDisplayMedia({'audio': false});
          if (kDebugMode) debugPrint("✅ Screen capture stream acquired successfully.");

          // 3. Listen for "Stop" from System UI
          // When user clicks "Stop sharing" in notification panel, this fires.
          var videoTrack = _localStream!.getVideoTracks()[0];
          videoTrack.onEnded = () {
            if (kDebugMode) debugPrint("📷 MEDIA TRACK ENDED: System 'Stop' button clicked.");
            _stopBroadcast();
          };

          videoTrack.onMute = () {
            if (kDebugMode) debugPrint(
                "🔇 MEDIA TRACK MUTED: Stream paused or stopped sending frames.");
            // Optional: If muted for extensive time, could treat as stop.
          };

          // 4. Listen for track removal (common in some implementations)
          _localStream!.onRemoveTrack = (track) {
            if (kDebugMode) debugPrint("👋 TRACK REMOVED from stream. Triggering termination.");
            _stopBroadcast();
          };

          // --- Session Lifecycle: Detect system stop ---
          for (var track in _localStream!.getTracks()) {
            track.onEnded = () {
              if (kDebugMode) debugPrint(
                  "🎥 [${track.kind}] system signal: track.onEnded triggered.");
              _stopBroadcast();
            };
          }
        } else if (Platform.isIOS) {
          // 0. Environment check
          final deviceInfo = DeviceInfoPlugin();
          final iosInfo = await deviceInfo.iosInfo;
          if (!iosInfo.isPhysicalDevice) {
            if (kDebugMode) debugPrint("❌ Environment Error: Simulator detected.");
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("iOS 模拟器不支持录屏，请使用真机")));
            setState(() => _isLoading = false);
            return;
          }

          // 1. First, Request Microphone permission
          if (kDebugMode) debugPrint("🎤 Step 1: Requesting Microphone permission...");
          await Permission.microphone.request();

          // 2. Second, Request Screen Capture via getDisplayMedia
          // This starts the socket server in the helper extension architecture.
          if (kDebugMode) debugPrint(
              "📸 Step 2: Starting socket server (deviceId: broadcast)...");
          _localStream = await navigator.mediaDevices.getDisplayMedia({
            'video': {
              'deviceId': 'broadcast',
            },
            'audio': false
          });
          if (kDebugMode) debugPrint(
              "✅ iOS Screen Capture stream prepared. Stream ID: ${_localStream?.id}");

          // (Removed manual triggerPicker here since flutter_webrtc natively triggers RPSystemBroadcastPickerView on iOS 14+)

          // 3. Signal user to pick
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("正在唤起录屏授权...")));

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

      // 3. Initialize Peer AFTER stream is acquired with robust ICE config
      final peer = Peer(
          id: code,
          options:
              PeerOptions(debug: LogLevel.All, config: _getIceServerConfig()));
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
          const channel0 = MethodChannel('castnow_picker');
          channel0.invokeMethod('minimizeApp');
        }

        // Active call to receiver
        if (_localStream != null) {
          final mediaConnection = _peer!.call(conn.peer, _localStream!);

          // --- ICE Debug Logs ---
          mediaConnection.peerConnection?.onIceConnectionState =
              (RTCIceConnectionState state) {
            if (kDebugMode) debugPrint("🔥 [发送端 ICE 状态]: ${state.toString()}");
          };
          mediaConnection.peerConnection?.onIceCandidate =
              (RTCIceCandidate candidate) {
            if (kDebugMode) debugPrint("🏠 [发送端候选地址]: ${candidate.candidate}");
          };
        }
      });

      // Start timer if not PRO
      if (!widget.isPro) {
        _remainingSeconds = 180;
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
      if (kDebugMode) debugPrint("Error starting broadcast: $e");

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
          if (kDebugMode) debugPrint(
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
        if (kDebugMode) debugPrint("❌ No video tracks found to switch.");
      }
    }
  }

  void _showTimeUpDialog() {
    if (!mounted) return;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              )
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isLandscape ? 24 : 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.timer_off_rounded,
                        color: Colors.orangeAccent, size: isLandscape ? 36 : 48),
                  ),
                  SizedBox(height: isLandscape ? 16 : 24),
                  const Text(
                    "Time Limit Reached",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Free version is limited to 3 minutes per session.\n\nPlease upgrade to PRO for unlimited casting.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 24 : 32),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleExit();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "CLOSE",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint("🧹 Disposing BroadcastScreenState");
    _limitTimer?.cancel();
    if (!_isStopping && _peer != null) {
      _stopBroadcast();
    }
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
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(15)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      color: _isScreenSharing
                                          ? Colors.blue
                                          : Colors.red,
                                      size: 10),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                        _isScreenSharing ? "SHARING" : "ON AIR",
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11)),
                                  ),
                                  if (!widget.isPro) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text("TRIAL:",
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                                            style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                              onPressed: () => _handleExit(),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon:
                                  const Icon(Icons.close, color: Colors.white))
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Constrained Video Preview (Enlarged and Dynamic Aspect)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        width: isLandscape ? 400 : double.infinity,
                        height: MediaQuery.of(context).size.height * (isLandscape ? 0.4 : 0.38),
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
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _peerId!
                                    .split('')
                                    .map((char) => Container(
                                          width: 32,
                                          height: 48,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2.5),
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
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: kPrimaryColor)),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (!_isScreenSharing)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: _switchCamera,
                                    icon: const Icon(Icons.flip_camera_ios,
                                        color: Colors.white),
                                    label: const Text("Switch",
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                  const SizedBox(width: 16),
                                  TextButton.icon(
                                    onPressed: _toggleMute,
                                    icon: Icon(
                                        _isMuted
                                            ? Icons.mic_off_rounded
                                            : Icons.mic_rounded,
                                        color: _isMuted
                                            ? Colors.redAccent
                                            : Colors.white),
                                    label: Text(_isMuted ? "Muted" : "Mute",
                                        style: TextStyle(
                                            color: _isMuted
                                                ? Colors.redAccent
                                                : Colors.white)),
                                  ),
                                ],
                              ),
                            if (_isScreenSharing)
                              TextButton.icon(
                                onPressed: _toggleMute,
                                icon: Icon(
                                    _isMuted
                                        ? Icons.mic_off_rounded
                                        : Icons.mic_rounded,
                                    color: _isMuted
                                        ? Colors.redAccent
                                        : Colors.white),
                                label: Text(_isMuted ? "Mic Muted" : "Mic On",
                                    style: TextStyle(
                                        color: _isMuted
                                            ? Colors.redAccent
                                            : Colors.white)),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _handleExit,
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
                    const SizedBox(height: 20),

                    // Native Picker removed since flutter_webrtc plugin handles it natively

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (_isLoading || _isStopping)
              Container(
                  color: Colors.black87,
                  child: Center(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: kPrimaryColor),
                      if (_isStopping) ...[
                        const SizedBox(height: 16),
                        const Text("正在结束直播...",
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ]
                    ],
                  ))),
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
      if (kDebugMode) debugPrint("[Signaling] Connected to server: $id");
      final conn = peer.connect(code);

      conn.on("open").listen((_) {
        if (kDebugMode) debugPrint("[Signaling] Connected to broadcaster signaling");
      });

      conn.on("close").listen((_) {
        if (kDebugMode) debugPrint("[Signaling] Disconnected from server.");
        if (mounted) {
          _showEndedDialog();
        }
      });
    });

    peer.on("call").listen((mediaConnection) async {
      if (kDebugMode) debugPrint("Received call from ${mediaConnection.peer}");

      // --- WebRTC Debug Logs ---
      mediaConnection.peerConnection?.onIceConnectionState =
          (RTCIceConnectionState state) {
        if (kDebugMode) debugPrint("🔥 [手机端 ICE 状态]: ${state.toString()}");
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          if (kDebugMode) debugPrint("❌ 警告：打洞失败，请检查代理设置或 STUN/TURN 服务器");
        }
      };

      mediaConnection.peerConnection?.onIceCandidate =
          (RTCIceCandidate candidate) {
        if (kDebugMode) debugPrint("🏠 [手机端候选地址]: ${candidate.candidate}");
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
        if (kDebugMode) debugPrint("Error creating dummy stream: $e");
        return;
      }

      mediaConnection.answer(dummyStream);
      mediaConnection.on("stream").listen((stream) {
        if (kDebugMode) debugPrint("Received remote stream: ${stream.id}");
        if (kDebugMode) debugPrint("Video tracks: ${stream.getVideoTracks().length}");
        if (stream.getVideoTracks().isNotEmpty) {
          if (kDebugMode) debugPrint(
              "Video track enabled: ${stream.getVideoTracks().first.enabled}");
        }

        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _isConnecting = false;
        });
      });

      mediaConnection.on("close").listen((_) {
        if (kDebugMode) debugPrint("Media connection closed");
        setState(() {
          _isConnected = false;
          _remoteRenderer.srcObject = null;
        });
      });

      mediaConnection.on("error").listen((e) {
        if (kDebugMode) debugPrint("Media connection error: $e");
      });
    });

    peer.on("error").listen((err) {
      if (kDebugMode) debugPrint("Peer Error: $err");
      if (mounted) {
        setState(() => _isConnecting = false);
        _showErrorDialog(
            "Could not connect to the stream. Please verify the access key is correct and ensure the broadcaster is still online.");
      }
    });
  }

  void _showEndedDialog() {
    if (!mounted) return;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              )
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isLandscape ? 24 : 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.videocam_off_rounded,
                        color: kPrimaryColor, size: isLandscape ? 36 : 48),
                  ),
                  SizedBox(height: isLandscape ? 16 : 24),
                  const Text(
                    "Broadcast Ended",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "The presenter has stop sharing their screen.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 24 : 32),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(); // Close dialog
                        Navigator.of(context).pop(); // Exit screen
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "BACK TO HOME",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              )
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isLandscape ? 24 : 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: isLandscape ? 36 : 48),
                  ),
                  SizedBox(height: isLandscape ? 16 : 24),
                  const Text(
                    "Connection Error",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 24 : 32),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "OK",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: isLandscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column: Label + Input
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("ENTER ACCESS KEY",
                                  style: TextStyle(
                                      color: kTextSecondary,
                                      letterSpacing: 2,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: TextField(
                                  controller: _codeController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: kPrimaryColor,
                                      letterSpacing: 4),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    filled: true,
                                    fillColor: kSurfaceColor,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 16),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none),
                                    hintText: "000000",
                                    hintStyle: TextStyle(
                                        color: kSurfaceColor.withBlue(40)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right Column: Button
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 240),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isConnecting ? null : _joinStream,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryColor,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16))),
                                    child: _isConnecting
                                        ? const CircularProgressIndicator(
                                            color: Colors.black)
                                        : const Text("CONNECT",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                letterSpacing: 1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        const Text("ENTER ACCESS KEY",
                            style: TextStyle(
                                color: kTextSecondary,
                                letterSpacing: 2,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: kPrimaryColor,
                                letterSpacing: 8),
                            decoration: InputDecoration(
                              counterText: "",
                              filled: true,
                              fillColor: kSurfaceColor,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 16),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              hintText: "000000",
                              hintStyle: TextStyle(
                                  color: kSurfaceColor.withBlue(40)),
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
                        ),
                        const SizedBox(height: 200),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
