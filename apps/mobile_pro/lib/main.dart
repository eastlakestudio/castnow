// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
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

// --- Constants & Theme ---
const Color kBackgroundColor = Color(0xFF030712);
const Color kSurfaceColor = Color(0xFF1E1B4B);
const Color kPrimaryColor = Color(0xFF6366F1);
const Color kTextPrimary = Color(0xFFF8FAFC);
const Color kTextSecondary = Color(0xFF94A3B8);

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
      title: 'CastNow Pro',
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
  final bool _isPro = true; // CastNow Pro features permanently unlocked.

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      final mode = url.startsWith('mailto:') 
          ? LaunchMode.platformDefault 
          : LaunchMode.externalApplication;
          
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode);
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content,
      {String? url, String? urlText}) {
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
                SelectableText(content, style: const TextStyle(color: kTextSecondary))),
        actions: [
          if (url != null)
            TextButton(
              onPressed: () => _launchURL(url),
              child: Text(urlText ?? "OPEN",
                  style: const TextStyle(
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
        Stack(
          clipBehavior: Clip.none,
          children: [
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
            const Positioned(
              top: -2,
              left: -2,
              child: Text(
                "PRO",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyanAccent,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.cyanAccent, blurRadius: 4),
                    Shadow(color: Colors.cyanAccent, blurRadius: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isLandscape ? 8 : 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'Cast'),
              TextSpan(text: 'Now', style: TextStyle(color: kPrimaryColor)),
              TextSpan(text: ' Pro', style: TextStyle(fontSize: 24, color: Colors.cyanAccent)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              const Text(
                "Receive on: ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => _launchURL("https://castnow.vercel.app"),
                child: const Text(
                  "castnow.vercel.app",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BroadcastScreen(isPro: _isPro))),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveScreen())),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final horizontalPadding = isWide ? 40.0 : 24.0;
            
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        isWide 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: brandSection),
                                Container(width: 1, height: 180, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 40)),
                                Expanded(child: actionsSection),
                              ],
                            )
                          : Column(
                              children: [
                                brandSection,
                                const SizedBox(height: 60),
                                actionsSection,
                              ],
                            ),
                        const SizedBox(height: 100),
                        _buildFooterLinks(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 32,
          runSpacing: 12,
          children: [
            _buildFooterLink(context, "SUPPORT", "Support & Feedback", "Need help or have a suggestion?\n\nOur team is dedicated to providing you with the best screen-sharing experience. If you encounter any issues or have ideas for new features, please don't hesitate to reach out.\n\nContact us at:\nmingh.liu@gmail.com", url: "mailto:mingh.liu@gmail.com", urlText: "SEND EMAIL"),
            _buildFooterLink(context, "PRIVACY", "Privacy Policy", "Your privacy is our top priority:\n\n1. P2P Technology: Data is transmitted directly between devices. No content ever passes through or is stored on our servers.\n2. No Personal Data: We do not collect your identity, contacts, or location.\n3. Zero Logs: We don't track your sessions or metadata.\n4. Local Device: Permissions are only used locally for broadcasting."),
            _buildFooterLink(context, "TERMS", "Terms of Service", "By using CastNow Pro, you agree to:\n\n1. Lawful Use: No illegal or harmful content.\n2. License: One-time purchase for personal/pro use.\n3. Disclaimer: Software provided 'as is'.\n4. Updates: Continuous improvements without guaranteed network-specific performance."),
          ],
        ),
        const SizedBox(height: 16),
        const Text("EASTLAKE STUDIO", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildFooterLink(BuildContext context, String label, String title, String content, {String? url, String? urlText}) {
    return GestureDetector(
      onTap: () => _showInfoDialog(context, title, content, url: url, urlText: urlText),
      child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
    );
  }

  Widget _buildActionButton(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required Color textColor, required VoidCallback onTap, bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24), border: isOutlined ? Border.all(color: Colors.white12) : null),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isOutlined ? Colors.white.withOpacity(0.05) : Colors.black12, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: textColor, size: 28)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
              ]),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: textColor.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

// --- Broadcast Screen ---
class BroadcastScreen extends StatefulWidget {
  final bool isPro;
  const BroadcastScreen({super.key, this.isPro = false});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> with WidgetsBindingObserver {
  Peer? _peer;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  String? _peerId;
  bool _isScreenSharing = false;
  bool _isLoading = false;
  bool _isStopping = false;
  String? _remoteDeviceInfo;
  bool _isConnected = false;

  // Source Selection
  bool _shareScreen = true;
  bool _shareCamera = true;
  bool _shareMic = true;
  bool _isMuted = true;

  Timer? _limitTimer;
  int _remainingSeconds = 180;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localRenderer.initialize();
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("📱 AppLifecycleState changed: $state");
  }

  void _toggleMute() {
    if (_localStream == null) return;
    setState(() {
      _isMuted = !_isMuted;
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    });
  }

  Future<void> _startBroadcast() async {
    if (!_shareScreen && !_shareCamera) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one video (Screen or Camera).")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final code = (100000 + math.Random().nextInt(900000)).toString();
      _localStream = null;
      
      // 1. Screen Sharing
      if (_shareScreen) {
        MediaStream? screenStream;
        if (Platform.isAndroid) {
          var status = await Permission.notification.status;
          if (status.isDenied) status = await Permission.notification.request();
          if (status.isGranted) {
            await const MethodChannel('castnow_picker').invokeMethod('startMediaProjectionService', {'type': 'mediaProjection', 'code': code});
            screenStream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
          }
        } else if (Platform.isIOS) {
          screenStream = await navigator.mediaDevices.getDisplayMedia({
            'video': {'deviceId': 'broadcast'},
            'audio': false
          });
        } else {
          screenStream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
        }

        if (screenStream != null && screenStream.getVideoTracks().isNotEmpty) {
          var track = screenStream.getVideoTracks()[0];
          _localStream ??= screenStream; 
          if (_localStream != screenStream) {
            _localStream!.addTrack(track);
          }
        }
      }

      // 2. Camera View
      if (_shareCamera) {
        if (!kIsWeb) await Permission.camera.request();
        MediaStream camStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': 1280,
            'height': 720,
            'frameRate': 30,
          }
        });
        if (camStream.getVideoTracks().isNotEmpty) {
          var track = camStream.getVideoTracks()[0];
          if (_localStream == null) {
            _localStream = camStream;
          } else {
            _localStream!.addTrack(track);
          }
        }
      }

      // 3. Microphone
      if (_shareMic) {
        if (!kIsWeb) await Permission.microphone.request();
        MediaStream micStream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false
        });
        if (micStream.getAudioTracks().isNotEmpty) {
          var audioTrack = micStream.getAudioTracks()[0];
          audioTrack.enabled = !_isMuted; // Start muted as requested
          if (_localStream == null) {
            _localStream = micStream;
          } else {
            _localStream!.addTrack(audioTrack);
          }
        }
      }

      if (_localStream == null) {
        throw Exception("Failed to acquire any media stream.");
      }

      _localRenderer.srcObject = _localStream;
      _isScreenSharing = _shareScreen;

      for (var track in _localStream!.getTracks()) {
        track.onEnded = () => _stopBroadcast();
      }

      await Future.delayed(const Duration(milliseconds: 1000));
      _connectWithRetry(code, _shareScreen, 0);

    } catch (e) {
      debugPrint("❌ Broadcast Start Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _connectWithRetry(String code, bool isScreen, int attempt) async {
    if (attempt > 5) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Connection Failed.")));
      return;
    }

    try {
      _peer?.dispose();
      _peer = Peer(id: code, options: PeerOptions(debug: LogLevel.All, config: {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun.miwifi.com:3478'},
        ]
      }));

      _peer!.on("open").listen((id) {
        if (mounted) setState(() { _peerId = id; _isLoading = false; });
      });

      _peer!.on("error").listen((error) {
        if (error.toString().contains("Failed host lookup")) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _peerId == null) _connectWithRetry(code, isScreen, attempt + 1);
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      });
      
      _peer!.on("connection").listen((conn) {
        _exchangeDeviceInfo(conn);
        if (_isScreenSharing && Platform.isAndroid) const MethodChannel('castnow_picker').invokeMethod('minimizeApp');
        
        if (_localStream != null && _localStream!.getTracks().isNotEmpty) {
          _peer!.call(conn.peer, _localStream!);
        }
        if (mounted) setState(() => _isConnected = true);
      });

      if (!widget.isPro) {
        _limitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() {
            if (_remainingSeconds > 0) { _remainingSeconds--; }
            else { timer.cancel(); _showTimeUpDialog(); }
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _exchangeDeviceInfo(DataConnection conn) async {
    final devInfo = DeviceInfoPlugin();
    String os = Platform.isIOS ? "iOS" : "Android";
    String model = "Device";
    if (Platform.isIOS) { model = (await devInfo.iosInfo).name; }
    else { model = (await devInfo.androidInfo).model; }
    
    void sendInfo() {
      conn.send({
        "type": "dev", 
        "os": os, 
        "model": model,
      });
    }

    conn.on("data").listen((data) {
      dynamic payload = data;
      if (data is String) {
        try { payload = jsonDecode(data); } catch (_) {}
      }
      if (payload is Map && payload["type"] == "dev") {
        String info = "${payload['os']} ${payload['model'] ?? ''}";
        if (payload['browser'] != null) info += " (${payload['browser']})";
        setState(() => _remoteDeviceInfo = info.trim());
      }
    });

    if (conn.open) { sendInfo(); } 
    else { conn.on("open").listen((_) => sendInfo()); }

    conn.on("close").listen((_) {
      if (mounted) setState(() { _isConnected = false; _remoteDeviceInfo = null; });
    });
  }

  void _stopBroadcast() async {
    if (!mounted || _isStopping) return;
    setState(() => _isStopping = true);
    _peer?.dispose();
    if (Platform.isAndroid) const MethodChannel('castnow_picker').invokeMethod('stopMediaProjectionService');
    _localStream?.dispose();
    _localRenderer.srcObject = null;
    if (mounted) { Navigator.pop(context); }
  }

  void _showTimeUpDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: const Text("Time Limit"), content: const Text("Upgrade to Pro for unlimited streaming."),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")), TextButton(onPressed: () => _stopBroadcast(), child: const Text("STOP"))],
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _limitTimer?.cancel();
    _localStream?.dispose();
    _localRenderer.dispose();
    _peer?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Widget _buildControl({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSourceTile(IconData icon, String label, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextPrimary)),
      secondary: Icon(icon, color: value ? kPrimaryColor : kTextSecondary),
      contentPadding: EdgeInsets.zero,
      activeColor: kPrimaryColor,
      checkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_peerId == null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Select Source"), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildSourceTile(Icons.phone_android, "Screen Desktop", _shareScreen, (val) => setState(() => _shareScreen = val!)),
                    const Divider(color: Colors.white10, height: 32),
                    _buildSourceTile(Icons.camera_alt, "Camera View", _shareCamera, (val) => setState(() => _shareCamera = val!)),
                    const Divider(color: Colors.white10, height: 32),
                    _buildSourceTile(Icons.mic, "Microphone", _shareMic, (val) => setState(() => _shareMic = val!)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 280,
                child: ElevatedButton(
                  onPressed: _startBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    shadowColor: kPrimaryColor.withOpacity(0.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded),
                      SizedBox(width: 12),
                      Text("START BROADCAST", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ],
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            Icon(Icons.circle, color: _isConnected ? Colors.green : (_isScreenSharing ? Colors.blue : Colors.red), size: 8),
                            const SizedBox(width: 8),
                            Text(_isConnected ? "CONNECTED" : (_isScreenSharing ? "SHARING" : "ON AIR"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if (_remoteDeviceInfo != null) ...[
                               const SizedBox(width: 8),
                               const Icon(Icons.link, color: Colors.green, size: 10),
                               const SizedBox(width: 4),
                               Text(_remoteDeviceInfo!, style: const TextStyle(fontSize: 10, color: kTextSecondary)),
                            ],
                            if (!widget.isPro) ...[
                               const SizedBox(width: 8),
                               Text("${(_remainingSeconds ~/ 60)}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 12)),
                            ]
                          ]),
                        ),
                        IconButton(onPressed: _stopBroadcast, icon: const Icon(Icons.close, color: Colors.white)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
                      clipBehavior: Clip.antiAlias,
                      child: _localStream != null ? RTCVideoView(_localRenderer, mirror: !_isScreenSharing) : Container(),
                    ),
                  ),
                  if (_peerId != null)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text("SHARING ACCESS KEY", style: TextStyle(color: kTextSecondary, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _peerId!.split('').map((char) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimaryColor.withOpacity(0.3))),
                            child: Text(char, style: const TextStyle(color: kPrimaryColor, fontSize: 32, fontWeight: FontWeight.bold)),
                          )).toList()),
                          if (!_isConnected) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 18),
                                  const SizedBox(width: 10),
                                  RichText(
                                    text: const TextSpan(
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      children: [
                                        TextSpan(text: "Open "),
                                        TextSpan(
                                          text: "castnow.vercel.app", 
                                          style: TextStyle(
                                            color: Colors.cyanAccent, 
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900, 
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.cyanAccent,
                                            letterSpacing: 0.5
                                          )
                                        ),
                                        TextSpan(text: " to receive"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                           const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  const SizedBox(height: 180),
                ],
              ),
            ),
            if (_localStream != null)
              Positioned(
                bottom: 40, left: 0, right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isPro) ...[
                      const Opacity(opacity: 0.8, child: Text("PRO EDITION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 4, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)]))),
                      const SizedBox(height: 12),
                    ],
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(color: kSurfaceColor.withOpacity(0.95), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white10), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildControl(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? "Unmute" : "Mute", color: _isMuted ? Colors.red : Colors.white, onTap: _toggleMute),
                            const SizedBox(width: 40),
                            _buildControl(icon: Icons.stop_circle, label: "Stop Recording", color: Colors.red, onTap: _stopBroadcast),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}


// --- Receive Screen (Simplified) ---
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});
  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final TextEditingController _codeController = TextEditingController();
  Peer? _peer;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _remoteDeviceInfo;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  void _join() {
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    setState(() => _isConnecting = true);
    _peer = Peer(options: PeerOptions(config: {'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]}));
    _peer!.on("open").listen((id) {
       final conn = _peer!.connect(code);
       _exchangeDeviceInfo(conn);
    });
    _peer!.on("call").listen((call) async {
        MediaStream ds = await navigator.mediaDevices.getUserMedia({'audio': false, 'video': false});
        call.answer(ds);
       call.on("stream").listen((s) {
         setState(() { _remoteRenderer.srcObject = s; _isConnected = true; _isConnecting = false; });
       });
       call.on("close").listen((_) => Navigator.pop(context));
    });
    _peer!.on("error").listen((_) => setState(() => _isConnecting = false));
  }

  void _exchangeDeviceInfo(DataConnection conn) async {
    final devInfo = DeviceInfoPlugin();
    String os = Platform.isIOS ? "iOS" : "Android";
    String model = "Device";
    if (Platform.isIOS) { model = (await devInfo.iosInfo).name; }
    else { model = (await devInfo.androidInfo).model; }
    
    void sendInfo() {
      final infoStr = jsonEncode({"type": "dev", "os": os, "model": model});
      conn.send(infoStr);
    }
    
    conn.on("data").listen((data) {
      if (data == null) return;
      dynamic payload = data;
      if (data is String) {
        try { payload = jsonDecode(data); } catch (_) {}
      }
      if (payload is Map && payload["type"] == "dev") {
        setState(() => _remoteDeviceInfo = "${payload['os']} ${payload['model'] ?? ''}");
      }
    });
    
    if (conn.open) {
      sendInfo();
    } else {
      conn.on("open").listen((_) => sendInfo());
    }
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
        RTCVideoView(_remoteRenderer),
        Positioned(top: 40, left: 16, child: Row(
          children: [
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            if (_remoteDeviceInfo != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, color: Colors.green, size: 12),
                    const SizedBox(width: 6),
                    Text("From: $_remoteDeviceInfo", style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ],
        )),
      ]));
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Join Stream")),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(
            controller: _codeController, textAlign: TextAlign.center, maxLength: 6, keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: kPrimaryColor, letterSpacing: 8),
            decoration: InputDecoration(
              filled: true,
              fillColor: kSurfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              hintText: "Enter 6-digit access code",
              hintStyle: TextStyle(color: kTextSecondary.withOpacity(0.3), fontSize: 16, letterSpacing: 0),
              counterText: "",
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: _join, child: _isConnecting ? const CircularProgressIndicator() : const Text("CONNECT"))),
        ]),
      ),
    );
  }
}
