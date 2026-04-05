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
import '../core/constants.dart';

class BroadcastScreen extends StatefulWidget {
  final bool isPro;
  const BroadcastScreen({super.key, this.isPro = false});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> with WidgetsBindingObserver {
  Peer? _peer;
  MediaStream? _localStream;
  MediaStream? _cameraPreviewStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _cameraRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteAudioRenderer = RTCVideoRenderer();
  String? _peerId;
  bool _isScreenSharing = false;
  MediaStreamTrack? _cameraTrack;
  bool _isLoading = false;
  bool _isStopping = false;
  bool _isConnected = false;

  // Source Selection
  bool _shareScreen = true;
  bool _shareCamera = false;
  bool _shareMic = true;
  bool _isMuted = true;
  bool _isRemoteMuted = false;
  
  // Subscription Tracking
  final List<StreamSubscription> _peerSubscriptions = [];

  void _clearPeerSubscriptions() {
    for (var s in _peerSubscriptions) { s.cancel(); }
    _peerSubscriptions.clear();
  }



  Timer? _limitTimer;
  int _remainingSeconds = 180;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localRenderer.initialize();
    _cameraRenderer.initialize();
    _remoteAudioRenderer.initialize();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localRenderer.dispose();
    _cameraRenderer.dispose();
    _remoteAudioRenderer.dispose();
    _localStream?.dispose();
    _cameraPreviewStream?.dispose();
    _limitTimer?.cancel();
    _clearPeerSubscriptions();
    _peer?.dispose();
    _peer = null;
    WakelockPlus.disable();
    super.dispose();
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

  void _toggleRemoteMute() {
    setState(() {
      _isRemoteMuted = !_isRemoteMuted;
      if (_remoteAudioRenderer.srcObject != null) {
        for (var track in _remoteAudioRenderer.srcObject!.getAudioTracks()) {
          track.enabled = !_isRemoteMuted;
        }
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_cameraTrack != null) {
      try {
        await Helper.switchCamera(_cameraTrack!);
      } catch (e) {
        debugPrint("❌ Switch Camera Error: $e");
      }
    }
  }

  Future<void> _startBroadcast() async {
    if (!_shareScreen && !_shareCamera) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one video (Screen or Camera).")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (Platform.isIOS) {
        await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
          appleAudioCategory: AppleAudioCategory.playAndRecord,
          appleAudioCategoryOptions: {
            AppleAudioCategoryOption.allowBluetooth,
            AppleAudioCategoryOption.defaultToSpeaker,
            AppleAudioCategoryOption.mixWithOthers
          },
          appleAudioMode: AppleAudioMode.videoChat,
        ));
      }

      final code = (100000 + math.Random().nextInt(900000)).toString();
      
      // 1. Initialize a clean Master Stream container
      // Use the first capture to initialize or start completely empty if supported
      _localStream = null;
      _cameraTrack = null;
      _cameraPreviewStream = null;

      // 2. Capture Screen (Broadcast Extension on iOS) - HIGH PRIORITY FOR TRACK 0
      if (_shareScreen) {
        debugPrint("📱 [BROADCAST] Capturing Screen...");
        MediaStream? screenStream;
        try {
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
        } catch (e) {
          debugPrint("⚠️ [BROADCAST] Screen capture failed: $e");
        }

        if (screenStream != null && screenStream.getVideoTracks().isNotEmpty) {
          _localStream = screenStream; // Screen is the base (track 0)
        }
        await Future.delayed(const Duration(milliseconds: 800)); // Grace period for iOS extension startup
      }

      // 3. Capture Camera (Secondary track)
      if (_shareCamera) {
        debugPrint("📸 [BROADCAST] Capturing Camera...");
        if (!kIsWeb) await Permission.camera.request();
        MediaStream camStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': 640,
            'height': 480,
            'frameRate': 24,
          }
        });
        if (camStream.getVideoTracks().isNotEmpty) {
          _cameraTrack = camStream.getVideoTracks()[0];
          _cameraPreviewStream = camStream;
          _cameraRenderer.srcObject = _cameraPreviewStream;
          
          if (_localStream == null) {
            _localStream = camStream;
          } else {
            _localStream!.addTrack(_cameraTrack!);
          }
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 4. Capture Microphone
      if (_shareMic) {
        debugPrint("🎙️ [BROADCAST] Capturing Microphone...");
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
          audioTrack.enabled = !_isMuted;
          
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

      // Finalize Local Preview
      _localRenderer.srcObject = _localStream;
      _isScreenSharing = _shareScreen;

      for (var track in _localStream!.getTracks()) {
        track.onEnded = () {
          debugPrint("⏹️ [TRACK] Track ended: ${track.kind} - ${track.label}");
          if (!_isStopping) _stopBroadcast();
        };
      }

      // Start PeerJS connection after all tracks are ready and added to the master stream
      debugPrint("📡 [BROADCAST] Ready to connect. Tracks: ${_localStream!.getTracks().length}");
      await Future.delayed(const Duration(milliseconds: 1000));
      _connectWithRetry(code, _shareScreen, 0);

    } catch (e) {
      debugPrint("❌ Broadcast Start Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Critical Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _connectWithRetry(String code, bool isScreen, int attempt) async {
    if (attempt > 8) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Signal Server Unavailable. Please check your internet connection."),
        duration: Duration(seconds: 5),
      ));
      return;
    }

    try {
      // 1. Thorough Cleanup of previous instance
      if (_peer != null) {
        debugPrint("🧹 [PEER] Cleaning up previous peer instance before retry...");
        _clearPeerSubscriptions();
        try {
          _peer!.dispose();
        } catch (e) {
          debugPrint("⚠️ [PEER] Dispose error (ignoring): $e");
        }
        _peer = null;
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 500 + (attempt * 1000)));
      }

      if (!mounted || _isStopping) return;

      debugPrint("📡 [PEER] Connecting to signal server (Attempt ${attempt + 1})...");
      
      _peer = Peer(id: code, options: PeerOptions(
        host: '0.peerjs.com',
        port: 443,
        path: '/',
        secure: true,
        debug: LogLevel.All,
        config: {
          'sdpSemantics': 'unified-plan',
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun.miwifi.com:3478'},
            {'urls': 'stun:stun.cdn.aliyun.com:3478'},
            {'urls': 'stun:stun.cloudflare.com:3478'},
          ]
        }
      ));

      // 2. Wrap all listeners in robust error handling
      _peerSubscriptions.add(_peer!.on("open").listen(
        (id) {
          debugPrint("✅ [PEER] Broadcast ready on ID: $id");
          if (mounted) setState(() { _peerId = id; _isLoading = false; });
        },
        onError: (e) => debugPrint("❌ [PEER] Open Stream Error: $e"),
        cancelOnError: false,
      ));

      _peerSubscriptions.add(_peer!.on("disconnected").listen(
        (_) {
          debugPrint("🔄 [PEER] Signaling disconnected.");
          if (mounted && _peer != null && !_peer!.destroyed && !_isStopping) {
            debugPrint("📢 [PEER] Attempting reconnect...");
            _peer!.reconnect();
          }
        },
        onError: (e) => debugPrint("❌ [PEER] Disconnect Stream Error: $e"),
      ));

      _peerSubscriptions.add(_peer!.on("close").listen(
        (_) {
          debugPrint("⛔ [PEER] Peer connection closed.");
          if (mounted && !_isStopping) {
            _connectWithRetry(code, isScreen, 0); 
          }
        },
        onError: (e) => debugPrint("❌ [PEER] Close Stream Error: $e"),
      ));

      _peerSubscriptions.add(_peer!.on("error").listen(
        (error) {
          debugPrint("❌ [PEER] Socket/Signal Error: $error");
          if (_isStopping) return;

          final errStr = error.toString().toLowerCase();
          bool shouldRetry = errStr.contains("failed host lookup") || 
                            errStr.contains("socketexception") ||
                            errStr.contains("unavailable-id") || 
                            errStr.contains("invalid-id") ||
                            errStr.contains("websocketchannelexception");

          if (shouldRetry) {
             debugPrint("🔄 [PEER] Recoverable error detected, retrying in 3s...");
             Future.delayed(const Duration(seconds: 3), () {
               if (mounted && !_isStopping) _connectWithRetry(code, isScreen, attempt + 1);
             });
          } else {
             if (mounted) setState(() => _isLoading = false);
          }
        },
        onError: (e) => debugPrint("❌ [PEER] Error Stream Exception: $e"),
      ));

      // 3. Listen for incoming DATA connections to trigger CALL back
      _peerSubscriptions.add(_peer!.on("connection").listen((dynamic conn) {
        if (conn is! DataConnection) return;
        debugPrint("🤝 [PEER] New receiver data connection: ${conn.peer}");
        
        // When a data connection opens, we CALL them back with our stream
        _peerSubscriptions.add(conn.on("open").listen((_) {
          debugPrint("📡 [PEER] Data channel open. Calling receiver back with stream...");
          if (_localStream != null) {
            final call = _peer!.call(conn.peer, _localStream!);
            _setupCallHandlers(call);
          }
        }));
      }));
      
      // 4. Listen for incoming CALLS (Viewer to Broadcaster intercom)
      _peerSubscriptions.add(_peer!.on("call").listen((call) {
        debugPrint("📞 [PEER] Incoming intercom call from receiver...");
        if (_localStream != null) {
          _setupCallHandlers(call);
          call.answer(_localStream!);
          
          if (_isScreenSharing && Platform.isAndroid) {
            const MethodChannel('castnow_picker').invokeMethod('minimizeApp');
          }
        }
      }, onError: (e) => debugPrint("❌ [PEER] Incoming Call Listener Error: $e")));

      if (!widget.isPro) {
        _limitTimer?.cancel();
        _limitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() {
            if (_remainingSeconds > 0) { _remainingSeconds--; }
            else { timer.cancel(); _showTimeUpDialog(); }
          });
        });
      }
    } catch (e) {
      debugPrint("❌ [PEER] Critical Connection Exception: $e");
      if (mounted && !_isStopping) {
        Future.delayed(const Duration(seconds: 5), () => _connectWithRetry(code, isScreen, attempt + 1));
      }
    }
  }

  void _setupCallHandlers(MediaConnection call) {
    _peerSubscriptions.add(call.on("stream").listen(
      (remoteStream) {
        debugPrint("🎙️ [PEER] Received talkback stream!");
        if (mounted) {
          setState(() {
            _isConnected = true;
            _remoteAudioRenderer.srcObject = remoteStream;
            for (var t in remoteStream.getAudioTracks()) { 
              t.enabled = !_isRemoteMuted; 
            }
          });
        }
      },
      onError: (e) => debugPrint("❌ [PEER] Call Stream Error: $e")
    ));

    _peerSubscriptions.add(call.on("close").listen((_) {
      debugPrint("⛔ [PEER] Receiver disconnected");
      if (mounted) setState(() => _isConnected = false);
    }));
  }



  void _stopBroadcast() async {
    if (!mounted || _isStopping) return;
    setState(() => _isStopping = true);
    _clearPeerSubscriptions();
    _peer?.dispose();
    _peer = null;
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

  Widget _buildControl({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label, 
              style: TextStyle(color: color.withOpacity(0.95), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.2),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: value ? LinearGradient(
            colors: [kPrimaryColor.withOpacity(0.2), kPrimaryColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: value ? null : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: value ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10,
            width: value ? 2 : 1,
          ),
          boxShadow: value ? [
            BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: -5),
            BoxShadow(color: kPrimaryColor.withOpacity(0.1), blurRadius: 10, spreadRadius: -2),
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: value ? Colors.cyanAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: value ? Colors.cyanAccent : kTextSecondary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: value ? Colors.white : kTextSecondary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: value ? Colors.white70 : kTextSecondary.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? Colors.cyanAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value ? Colors.cyanAccent : Colors.white24, width: 2),
              ),
              child: value ? const Icon(Icons.check, size: 16, color: kBackgroundColor) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipBar() {
    if (_isConnected) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              children: [
                TextSpan(text: "Open "),
                TextSpan(
                  text: "castnow.vercel.app", 
                  style: TextStyle(
                    color: Colors.cyanAccent, 
                    fontWeight: FontWeight.w800, 
                    decoration: TextDecoration.underline,
                  )
                ),
                TextSpan(text: " to receive"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_peerId == null && !_isLoading) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.5,
              colors: [kPrimaryColor.withOpacity(0.05), Colors.transparent],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.cyanAccent, size: 40),
                    const SizedBox(height: 16),
                    const Text("SELECT SOURCES", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    const Text("Select what to broadcast to the receiver", style: TextStyle(color: kTextSecondary, fontSize: 13)),
                    const SizedBox(height: 40),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          _buildSourceCard(
                            icon: Icons.phone_android_rounded, 
                            title: "Screen Mirror", 
                            subtitle: "Broadcast your entire iOS screen", 
                            value: _shareScreen, 
                            onChanged: (val) {
                              if (!val && !_shareCamera) return; // Force at least one
                              setState(() {
                                _shareScreen = val;
                                if (val) _shareCamera = false;
                              });
                            }
                          ),
                          _buildSourceCard(
                            icon: Icons.videocam_rounded, 
                            title: "Camera View", 
                            subtitle: "Share high-quality camera stream", 
                            value: _shareCamera, 
                            onChanged: (val) {
                              if (!val && !_shareScreen) return; // Force at least one
                              setState(() {
                                _shareCamera = val;
                                if (val) _shareScreen = false;
                              });
                            }
                          ),
                          _buildSourceCard(
                            icon: Icons.mic_rounded, 
                            title: "HD Microphone", 
                            subtitle: "Capture crystal clear audio (Muted by default)", 
                            value: _shareMic, 
                            onChanged: (val) => setState(() => _shareMic = val)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 320,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _startBroadcast,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("START BROADCAST", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
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
                      child: _localStream != null ? Builder(builder: (context) {
                        final hasBoth = _isScreenSharing && _shareCamera;

                        if (!hasBoth) {
                          final activeRenderer = _isScreenSharing ? _localRenderer : _cameraRenderer;
                          return RTCVideoView(activeRenderer, mirror: _shareCamera && !_isScreenSharing);
                        } else {
                          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                          return Flex(
                            direction: isLandscape ? Axis.horizontal : Axis.vertical,
                            children: [
                              // Screen sharing takes priority/equal space
                              Expanded(child: RTCVideoView(_localRenderer, mirror: false)),
                              Container(
                                width: isLandscape ? 1 : double.infinity, 
                                height: isLandscape ? double.infinity : 1, 
                                color: Colors.white10
                              ),
                              // Camera view
                              Expanded(child: RTCVideoView(_cameraRenderer, mirror: true)),
                            ],
                          );
                        }
                      }) : Container(),
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
                            // Tip bar removed from here as it's now in the fixed bottom overlay
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
                bottom: 30, left: 16, right: 16,
                child: Builder(builder: (context) {
                  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                  
                  final controlBar = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kSurfaceColor.withOpacity(0.95), 
                      borderRadius: BorderRadius.circular(40), 
                      border: Border.all(color: Colors.white10), 
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_shareCamera)
                          _buildControl(icon: Icons.flip_camera_ios_rounded, label: "Flip", color: Colors.white, onTap: _switchCamera),
                        _buildControl(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? "Unmute" : "Mute", color: _isMuted ? Colors.red : Colors.white, onTap: _toggleMute),
                        _buildControl(icon: _isRemoteMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, label: "Talk", color: _isRemoteMuted ? Colors.white24 : Colors.cyanAccent, onTap: _toggleRemoteMute),
                        
                        Container(height: 24, width: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 4)),
                        _buildControl(icon: Icons.stop_circle, label: "Stop", color: Colors.redAccent, onTap: _stopBroadcast),
                      ],
                    ),
                  );

                  if (isLandscape) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isPro) ...[
                          const Opacity(opacity: 0.8, child: Text("PRO EDITION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 4, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)]))),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            controlBar,
                            const SizedBox(width: 16),
                            _buildTipBar(),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isPro) ...[
                          const Opacity(opacity: 0.8, child: Text("PRO EDITION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 4, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)]))),
                          const SizedBox(height: 12),
                        ],
                        controlBar,
                        const SizedBox(height: 12),
                        _buildTipBar(),
                      ],
                    );
                  }
                }),
              ),
            if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
