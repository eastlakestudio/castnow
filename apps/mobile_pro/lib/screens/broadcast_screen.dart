import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/subscription_service.dart';
import '../widgets/paywall_dialog.dart';
import '../core/rtmp_settings_service.dart';
import '../l10n/app_localizations.dart';

class BroadcastScreen extends StatefulWidget {
  final bool isPro;
  const BroadcastScreen({super.key, this.isPro = false});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen>
    with WidgetsBindingObserver {
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
  String? _receiverInfo;

  // Source Selection
  bool _shareScreen = true;
  bool _shareCamera = false;
  bool _shareMic = true;
  bool _isMuted = true;
  bool _isRemoteMuted = false;

  // RTMP settings
  bool _isRtmpMode = false;
  final TextEditingController _rtmpUrlController = TextEditingController();
  final TextEditingController _rtmpKeyController = TextEditingController();

  // Subscription Tracking
  final List<StreamSubscription> _peerSubscriptions = [];
  final List<MediaConnection> _activeCalls = [];

  void _clearPeerSubscriptions() {
    for (var s in _peerSubscriptions) {
      s.cancel();
    }
    _peerSubscriptions.clear();
  }

  Timer? _limitTimer;
  int _remainingSeconds = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localRenderer.initialize();
    _cameraRenderer.initialize();
    _remoteAudioRenderer.initialize();

    _localRenderer.onResize = () {
      debugPrint(
          "🖥️ [_localRenderer RESIZE] width: ${_localRenderer.videoWidth}, height: ${_localRenderer.videoHeight}");
    };
    _cameraRenderer.onResize = () {
      debugPrint(
          "🖥️ [_cameraRenderer RESIZE] width: ${_cameraRenderer.videoWidth}, height: ${_cameraRenderer.videoHeight}");
    };

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
    _rtmpUrlController.dispose();
    _rtmpKeyController.dispose();
    final p = _peer;
    _peer = null;
    Future.delayed(const Duration(milliseconds: 500), () => p?.dispose());
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Please select at least one video (Screen or Camera).")));
      return;
    }

    final isPro =
        context.read<SubscriptionService>().isSubscribed || widget.isPro;

    if (_isRtmpMode) {
      if (!isPro) {
        showDialog(context: context, builder: (_) => const PaywallDialog());
        return;
      }
      if (_rtmpUrlController.text.trim().isEmpty) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.rtmpUrlRequired),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }

    // Save RTMP settings to Native AppGroup (Shared Defaults) - Only required for iOS Broadcast Extension
    if (Platform.isIOS) {
      await RtmpSettingsService.saveSettings(
        mode: _isRtmpMode ? 'rtmp' : 'webrtc',
        url: _rtmpUrlController.text.trim(),
        key: _rtmpKeyController.text.trim(),
      );
    }

    if (!isPro) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                  child: Text(
                      "Free Version: Streaming is limited to 2 minutes.",
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: Colors.blueGrey.shade800,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
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

      // 1. Initialize track collector
      List<MediaStreamTrack> collectedTracks = [];
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
            if (status.isDenied)
              status = await Permission.notification.request();
            if (status.isGranted) {
              await const MethodChannel('castnow_picker').invokeMethod(
                  'startMediaProjectionService',
                  {'type': 'mediaProjection', 'code': code});
              screenStream = await navigator.mediaDevices
                  .getDisplayMedia({'video': true, 'audio': false});
            }
          } else if (Platform.isIOS) {
            screenStream = await navigator.mediaDevices.getDisplayMedia({
              'video': {
                'deviceId': 'broadcast',
                'frameRate': 24,
                'width': {'ideal': 1280},
                'height': {'ideal': 720}
              },
              'audio': false
            });
          } else {
            screenStream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
          }
        } catch (e) {
          debugPrint("⚠️ [BROADCAST] Screen capture failed: $e");
        }

        if (screenStream != null && screenStream.getVideoTracks().isNotEmpty) {
          final track = screenStream.getVideoTracks()[0];
          collectedTracks.add(track);
          debugPrint(
              "🔍 [TRACK SETTINGS] id: ${track.id}, kind: ${track.kind}, enabled: ${track.enabled}");
          try {
            debugPrint("🔍 [TRACK SETTINGS] settings: ${track.getSettings()}");
          } catch (e) {
            debugPrint("🔍 [TRACK SETTINGS] settings query error: $e");
          }
        }
        await Future.delayed(const Duration(
            milliseconds: 800)); // Grace period for iOS extension startup
      }

      // 3. Capture Camera (Secondary track)
      if (_shareCamera) {
        debugPrint("📸 [BROADCAST] Capturing Camera...");
        if (!kIsWeb && !Platform.isMacOS) await Permission.camera.request();
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
          collectedTracks.add(_cameraTrack!);
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 4. Capture Microphone
      if (_shareMic) {
        debugPrint("🎙️ [BROADCAST] Capturing Microphone...");
        if (!kIsWeb && !Platform.isMacOS) await Permission.microphone.request();
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
          collectedTracks.add(audioTrack);
        }
      }

      if (collectedTracks.isEmpty) {
        throw Exception("Failed to acquire any media tracks.");
      }

      // Combine into a fresh master stream to avoid track mapping bugs
      _localStream = await createLocalMediaStream('master_stream');
      for (var track in collectedTracks) {
        await _localStream!.addTrack(track);
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

      if (Platform.isMacOS && _isRtmpMode) {
        debugPrint("📡 [BROADCAST] Starting macOS native RTMP push...");
        try {
          await const MethodChannel('com.eastlakestudio.castnow.pro/rtmp_macos')
              .invokeMethod('startRtmpBroadcast', {
            'url': _rtmpUrlController.text.trim(),
            'key': _rtmpKeyController.text.trim(),
          });
          if (mounted) setState(() => _isLoading = false);
        } catch (e) {
          debugPrint("❌ [Mac RTMP Error]: $e");
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("RTMP Error: $e")));
          }
        }
        return; // Skip WebRTC P2P
      }

      // Start PeerJS connection after all tracks are ready and added to the master stream
      debugPrint(
          "📡 [BROADCAST] Ready to connect. Tracks: ${_localStream!.getTracks().length}");
      await Future.delayed(const Duration(milliseconds: 1000));
      _connectWithRetry(code, _shareScreen, 0);
    } catch (e) {
      debugPrint("❌ Broadcast Start Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Critical Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _connectWithRetry(String code, bool isScreen, int attempt) async {
    if (attempt > 8) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "Signal Server Unavailable. Please check your internet connection."),
        duration: Duration(seconds: 5),
      ));
      return;
    }

    try {
      // 1. Thorough Cleanup of previous instance
      if (_peer != null) {
        debugPrint(
            "🧹 [PEER] Cleaning up previous peer instance before retry...");
        _clearPeerSubscriptions();
        final p = _peer;
        _peer = null;
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            p?.dispose();
          } catch (e) {
            debugPrint("⚠️ [PEER] Dispose error (ignoring): $e");
          }
        });
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 500 + (attempt * 1000)));
      }

      if (!mounted || _isStopping) return;

      debugPrint(
          "📡 [PEER] Connecting to signal server (Attempt ${attempt + 1})...");

      _peer = Peer(
          id: code,
          options: PeerOptions(
              host: '0.peerjs.com',
              port: 443,
              path: '/',
              secure: true,
              debug: LogLevel.Errors,
              config: {
                'iceServers': [
                  {'urls': 'stun:stun.l.google.com:19302'},
                  {'urls': 'stun:stun.miwifi.com:3478'},
                  {'urls': 'stun:stun.cdn.aliyun.com:3478'},
                  {'urls': 'stun:stun.cloudflare.com:3478'},
                ]
              }));

      // 2. Wrap all listeners in robust error handling
      _peerSubscriptions.add(_peer!.on("open").listen(
        (id) {
          debugPrint("✅ [PEER] Broadcast ready on ID: $id");
          if (mounted)
            setState(() {
              _peerId = id;
              _isLoading = false;
            });
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
            debugPrint(
                "🔄 [PEER] Recoverable error detected, retrying in 3s...");
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && !_isStopping)
                _connectWithRetry(code, isScreen, attempt + 1);
            });
          } else {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        onError: (e) => debugPrint("❌ [PEER] Error Stream Exception: $e"),
      ));

      // 3. v9.1 Media-Only Handshake: Unified handler for 'Knock' and 'Intercom'
      _peerSubscriptions.add(_peer!.on("call").listen((dynamic incoming) {
        if (incoming is! MediaConnection) return;
        final remoteCall = incoming;
        debugPrint(
            "🤝 [v9.1] BROADCASTER: Incoming call from: ${remoteCall.peer}");

        // A. Identify 'Knock' (Using CVN ID format and not yet connected)
        if (remoteCall.peer.startsWith("cnv_") && !_isConnected) {
          debugPrint(
              "🏁 [v9.1] Detected 'Media Knock'. Parsing metadata & recalling...");

          final parts = remoteCall.peer.split("_");
          if (parts.length >= 3 && mounted) {
            setState(() => _receiverInfo = "${parts[1]} on ${parts[2]}");
          }

          // Flash Close and Recall: Add a tiny delay and try-catch to prevent peerdart crash
          Future.delayed(const Duration(milliseconds: 100), () {
            try {
              remoteCall.close();
            } catch (e) {
              debugPrint("⚠️ Peerdart close-after-event suppression: $e");
            }
          });

          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_localStream != null && _peer != null && mounted) {
              // Peerdart 0.5.6 supports metadata as a named parameter
              final recall = _peer!.call(remoteCall.peer, _localStream!);
              _activeCalls.add(recall);
              _setupCallHandlers(recall);
              setState(() => _isConnected = true);
            }
          });
        } else {
          // B. Treat as Intercom / Standard Call
          debugPrint("📞 [v9.1] Answering standard/intercom call...");
          if (_localStream != null && mounted) {
            _setupCallHandlers(remoteCall);
            remoteCall.answer(_localStream!);

            if (_isScreenSharing && Platform.isAndroid) {
              const MethodChannel('castnow_picker').invokeMethod('minimizeApp');
            }
          }
        }
      }, onError: (e) => debugPrint("❌ [v9.1] Call Listener Error: $e")));

      if (!widget.isPro && !context.read<SubscriptionService>().isSubscribed) {
        _limitTimer?.cancel();
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
    } catch (e) {
      debugPrint("❌ [PEER] Critical Connection Exception: $e");
      if (mounted && !_isStopping) {
        Future.delayed(const Duration(seconds: 5),
            () => _connectWithRetry(code, isScreen, attempt + 1));
      }
    }
  }

  void _setupCallHandlers(MediaConnection call) {
    if (!_activeCalls.contains(call)) _activeCalls.add(call);

    final pc = call.peerConnection;

    _peerSubscriptions.add(call.on("stream").listen((remoteStream) {
      debugPrint("🎙️ [PEER] Received talkback stream!");
      if (remoteStream.getAudioTracks().isNotEmpty && (Platform.isAndroid || Platform.isIOS)) {
        Helper.setSpeakerphoneOn(true);
      }
      if (mounted) {
        setState(() {
          _isConnected = true;
          _remoteAudioRenderer.srcObject = remoteStream;
          for (var t in remoteStream.getAudioTracks()) {
            t.enabled = !_isRemoteMuted;
          }
        });
      }
    }, onError: (e) => debugPrint("❌ [PEER] Call Stream Error: $e")));

    _peerSubscriptions.add(call.on("close").listen((_) {
      debugPrint("⛔ [PEER] Call connection closed");
      _activeCalls.remove(call);
      if (mounted && _activeCalls.isEmpty) {
        setState(() => _isConnected = false);
      }
    }));
  }



  void _stopBroadcast() async {
    if (!mounted || _isStopping) return;
    setState(() => _isStopping = true);

    // Explicitly close all active calls to signal the receivers
    debugPrint(
        "🛑 [v9.1] Closing ${_activeCalls.length} active calls before stopping...");
    for (var call in List.from(_activeCalls)) {
      try {
        debugPrint("📡 [v9.1] Sending BYE to receiver: ${call.peer}");
        call.close();
      } catch (e) {
        debugPrint("⚠️ Error closing call: $e");
      }
    }
    _activeCalls.clear();

    _clearPeerSubscriptions();
    final p = _peer;
    _peer = null;

    // Give some time for 'close' packets to fly before destroying the peer
    Future.delayed(const Duration(milliseconds: 300), () {
      debugPrint("🧹 [v9.1] Disposing Peer instance...");
      p?.dispose();
    });
    if (Platform.isAndroid) {
      const MethodChannel('castnow_picker')
          .invokeMethod('stopMediaProjectionService');
    }
    if (Platform.isMacOS && _isRtmpMode) {
      try {
        const MethodChannel('com.eastlakestudio.castnow.pro/rtmp_macos')
            .invokeMethod('stopRtmpBroadcast');
      } catch (e) {
        debugPrint("⚠️ Mac RTMP Stop Error: $e");
      }
    }
    _localStream?.dispose();
    _localRenderer.srcObject = null;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showTimeUpDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              backgroundColor: kSurfaceColor,
              title: const Text("Time Limit Reached",
                  style: TextStyle(color: Colors.cyanAccent)),
              content: const Text(
                  "Free streaming is limited to 2 minutes.\nUpgrade to PRO to continue this broadcast.",
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _stopBroadcast();
                    },
                    child: const Text("STOP",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showDialog(
                          context: context,
                          builder: (_) => const PaywallDialog()).then((_) {
                        if (mounted &&
                            !context.read<SubscriptionService>().isSubscribed) {
                          _stopBroadcast();
                        }
                      });
                    },
                    child: const Text("UPGRADE TO PRO",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ));
  }

  Widget _buildControl(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
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
              style: TextStyle(
                  color: color.withOpacity(0.95),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required Function(bool) onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(
                  colors: [
                    kPrimaryColor.withOpacity(0.2),
                    kPrimaryColor.withOpacity(0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: value ? null : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: value ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10,
            width: value ? 2 : 1,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: -5),
                  BoxShadow(
                      color: kPrimaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: -2),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: value
                    ? Colors.cyanAccent.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon,
                  color: value ? Colors.cyanAccent : kTextSecondary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: value ? Colors.white : kTextSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: value
                              ? Colors.white70
                              : kTextSecondary.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
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
                border: Border.all(
                    color: value ? Colors.cyanAccent : Colors.white24,
                    width: 2),
              ),
              child: value
                  ? const Icon(Icons.check, size: 16, color: kBackgroundColor)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenSharingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.cyan.withOpacity(0.15),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withOpacity(0.05),
                border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.2), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.screen_share_rounded,
                color: Colors.cyanAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Screen Mirroring Active",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Sharing entire screen...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
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
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              children: [
                TextSpan(text: "Open "),
                TextSpan(
                    text: "castnow.vercel.app",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    )),
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
    final isPro =
        context.watch<SubscriptionService>().isSubscribed || widget.isPro;
    if (isPro) {
      _limitTimer?.cancel();
    }

    if (_peerId == null && !_isLoading) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Stack(
          children: [
            Positioned(
              top: 50,
              left: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
            Container(
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.cyanAccent, size: 40),
                        const SizedBox(height: 16),
                        const Text("SELECT SOURCES",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                        const SizedBox(height: 8),
                        const Text("Select what to broadcast to the receiver",
                            style: TextStyle(color: kTextSecondary, fontSize: 13)),
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
                                    HapticFeedback.selectionClick();
                                    if (!val && !_shareCamera)
                                      return; // Force at least one
                                    setState(() {
                                      _shareScreen = val;
                                      if (val) _shareCamera = false;
                                    });
                                  }),
                              _buildSourceCard(
                                  icon: Icons.videocam_rounded,
                                  title: "Camera View",
                                  subtitle: "Share high-quality camera stream",
                                  value: _shareCamera,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    if (!val && !_shareScreen)
                                      return; // Force at least one
                                    setState(() {
                                      _shareCamera = val;
                                      if (val) _shareScreen = false;
                                    });
                                  }),
                              _buildSourceCard(
                                  icon: Icons.mic_rounded,
                                  title: "HD Microphone",
                                  subtitle:
                                      "Capture crystal clear audio (Muted by default)",
                                  value: _shareMic,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _shareMic = val);
                                  }),
                              _buildSourceCard(
                                  icon: Icons.rss_feed_rounded,
                                  title: "RTMP Mode",
                                  subtitle:
                                      "Broadcast to RTMP server (YouTube, Twitch, etc.)",
                                  value: _isRtmpMode,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    if (val && !isPro) {
                                      showDialog(
                                          context: context,
                                          builder: (_) => const PaywallDialog());
                                      return;
                                    }
                                    setState(() => _isRtmpMode = val);
                                  }),
                              if (_isRtmpMode) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _rtmpUrlController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: "RTMP URL",
                                    labelStyle:
                                        const TextStyle(color: Colors.white54),
                                    hintText: "rtmp://your-server/live",
                                    hintStyle:
                                        const TextStyle(color: Colors.white24),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                          color: Colors.white10),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                          color: Colors.white10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                          color: Colors.cyanAccent),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _rtmpKeyController,
                                  obscureText: true,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: "Stream Key",
                                    labelStyle:
                                        const TextStyle(color: Colors.white54),
                                    hintText: "Enter stream key",
                                    hintStyle:
                                        const TextStyle(color: Colors.white24),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                          color: Colors.white10),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                          color: Colors.white10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                          color: Colors.cyanAccent),
                                    ),
                                  ),
                                ),
                              ],
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
                                BoxShadow(
                                    color: kPrimaryColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _startBroadcast,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 22),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("START BROADCAST",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: 1.5)),
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
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusOverlay = Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.circle,
                  color: _isConnected
                      ? Colors.green
                      : (_isScreenSharing ? Colors.blue : Colors.red),
                  size: 8),
              const SizedBox(width: 8),
              Text(
                  _isConnected
                      ? "CONNECTED"
                      : (_isScreenSharing ? "SHARING" : "ON AIR"),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              if (!isPro) ...[
                const SizedBox(width: 8),
                Text(
                    "${(_remainingSeconds ~/ 60)}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 12)),
              ]
            ]),
          ),
          Container(
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(
                onPressed: _stopBroadcast,
                icon: const Icon(Icons.close, color: Colors.white, size: 20)),
          ),
        ],
      ),
    );

    final pairCodeWidget = _peerId != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("SHARING ACCESS KEY",
                  style: TextStyle(
                      color: kTextSecondary,
                      letterSpacing: 2,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _peerId!
                        .split('')
                        .map((char) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: kPrimaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: kPrimaryColor.withOpacity(0.3))),
                              child: Text(char,
                                  style: const TextStyle(
                                      color: kPrimaryColor,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold)),
                            ))
                        .toList()),
              ),
              if (_isConnected && _receiverInfo != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.devices_rounded,
                          color: Colors.green, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        "Receiver: $_receiverInfo",
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ] else if (!_isConnected)
                const SizedBox(height: 12),
            ],
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Stack(children: [
                      Container(
                        height: isLandscape
                            ? MediaQuery.of(context).size.height * 0.45
                            : MediaQuery.of(context).size.height * 0.35,
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10)),
                        clipBehavior: Clip.antiAlias,
                        child: _localStream != null
                            ? Builder(builder: (context) {
                                final hasBoth =
                                    _isScreenSharing && _shareCamera;

                                if (!hasBoth) {
                                  if (_isScreenSharing) {
                                    return _buildScreenSharingPlaceholder();
                                  } else {
                                    return RTCVideoView(_cameraRenderer,
                                        mirror: true);
                                  }
                                } else {
                                  return Flex(
                                    direction: isLandscape
                                        ? Axis.horizontal
                                        : Axis.vertical,
                                    children: [
                                      // Screen sharing placeholder to prevent local loops
                                      Expanded(
                                          child: _buildScreenSharingPlaceholder()),
                                      Container(
                                          width:
                                              isLandscape ? 1 : double.infinity,
                                          height:
                                              isLandscape ? double.infinity : 1,
                                          color: Colors.white10),
                                      // Camera view
                                      Expanded(
                                          child: RTCVideoView(_cameraRenderer,
                                              mirror: true)),
                                    ],
                                  );
                                }
                              })
                            : Container(),
                      ),
                      if (_localStream != null) statusOverlay,
                    ]),
                  ),
                  if (!isLandscape && _peerId != null)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: pairCodeWidget,
                    ),
                  const SizedBox(height: 180),
                ],
              ),
            ),
            if (_localStream != null)
              Positioned(
                bottom: 30,
                left: 16,
                right: 16,
                child: Builder(builder: (context) {
                  final isLandscape = MediaQuery.of(context).orientation ==
                      Orientation.landscape;

                  final controlBar = Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: kSurfaceColor.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 20)
                        ]),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_shareCamera)
                          _buildControl(
                              icon: Icons.flip_camera_ios_rounded,
                              label: "Flip",
                              color: Colors.white,
                              onTap: _switchCamera),
                        _buildControl(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            label: _isMuted ? "Unmute" : "Mute",
                            color: _isMuted ? Colors.red : Colors.white,
                            onTap: _toggleMute),
                        _buildControl(
                            icon: _isRemoteMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            label: "Talk",
                            color: _isRemoteMuted
                                ? Colors.white24
                                : Colors.cyanAccent,
                            onTap: _toggleRemoteMute),
                        Container(
                            height: 24,
                            width: 1,
                            color: Colors.white10,
                            margin: const EdgeInsets.symmetric(horizontal: 4)),
                        _buildControl(
                            icon: Icons.stop_circle,
                            label: "Stop",
                            color: Colors.redAccent,
                            onTap: _stopBroadcast),
                      ],
                    ),
                  );

                  if (isLandscape) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_peerId != null) Expanded(child: pairCodeWidget),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isPro) ...[
                              const Opacity(
                                  opacity: 0.8,
                                  child: Text("PRO EDITION",
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.cyanAccent,
                                          letterSpacing: 4,
                                          shadows: [
                                            Shadow(
                                                color: Colors.cyanAccent,
                                                blurRadius: 8)
                                          ]))),
                              const SizedBox(height: 12),
                            ],
                            controlBar,
                            const SizedBox(height: 12),
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
                          const Opacity(
                              opacity: 0.8,
                              child: Text("PRO EDITION",
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.cyanAccent,
                                      letterSpacing: 4,
                                      shadows: [
                                        Shadow(
                                            color: Colors.cyanAccent,
                                            blurRadius: 8)
                                      ]))),
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
            if (_isLoading)
              Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
