import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/subscription_service.dart';
import '../core/rtmp_settings_service.dart';
import '../l10n/app_strings.dart';
import '../services/webrtc_broadcast_service.dart';
import '../services/media_capture_service.dart';
import '../widgets/paywall_dialog.dart';
import '../widgets/source_selector.dart';
import '../widgets/broadcast_controls.dart';
import '../widgets/code_display.dart';
import '../widgets/glass_container.dart';

class BroadcastScreen extends StatefulWidget {
  final bool isPro;
  const BroadcastScreen({super.key, this.isPro = false});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen>
    with WidgetsBindingObserver {
  // --- Services ---
  final _webrtc = WebrtcBroadcastService();

  // --- Media ---
  MediaStream? _localStream;
  MediaStream? _cameraPreviewStream;
  MediaStreamTrack? _cameraTrack;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _cameraRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteAudioRenderer = RTCVideoRenderer();

  // --- Source Selection ---
  bool _shareScreen = true;
  bool _shareCamera = false;
  bool _shareMic = true;
  bool _isMuted = true;
  bool _isRemoteMuted = false;
  bool _isScreenSharing = false;

  // --- RTMP ---
  bool _isRtmpMode = false;
  final TextEditingController _rtmpUrlController = TextEditingController();
  final TextEditingController _rtmpKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localRenderer.initialize();
    _cameraRenderer.initialize();
    _remoteAudioRenderer.initialize();
    _setupServiceCallbacks();
    WakelockPlus.enable();
  }

  void _setupServiceCallbacks() {
    _webrtc.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _webrtc.onShowSnackBar = (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    };
    _webrtc.onTimeUp = (limitText) => _showTimeUpDialog(limitText);
    _webrtc.onRemoteAudioStream = (remoteStream) {
      if (remoteStream.getAudioTracks().isNotEmpty && Platform.isIOS) {
        Helper.setSpeakerphoneOn(true);
      }
      if (mounted) {
        setState(() {
          _remoteAudioRenderer.srcObject = remoteStream;
          for (var t in remoteStream.getAudioTracks()) {
            t.enabled = !_isRemoteMuted;
          }
        });
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localRenderer.dispose();
    _cameraRenderer.dispose();
    _remoteAudioRenderer.dispose();
    _localStream?.dispose();
    _cameraPreviewStream?.dispose();
    _webrtc.dispose();
    _rtmpUrlController.dispose();
    _rtmpKeyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do NOT stop broadcast on background/inactive — iOS Broadcast Extension
    // and RTMP streaming are designed to run in the background. Only stop
    // when the user explicitly taps the stop button.
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enabled = !_isMuted;
        }
      }
    });
  }

  void _toggleRemoteMute() {
    setState(() {
      _isRemoteMuted = !_isRemoteMuted;
      if (_remoteAudioRenderer.srcObject != null) {
        for (var track
            in _remoteAudioRenderer.srcObject!.getAudioTracks()) {
          track.enabled = !_isRemoteMuted;
        }
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_cameraTrack != null) {
      await MediaCaptureService.switchCamera(_cameraTrack!);
    }
  }

  Future<void> _startBroadcast() async {
    if (!_shareScreen && !_shareCamera) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please select at least one video (Screen or Camera).')));
      return;
    }

    final isPro =
        context.read<SubscriptionService>().isSubscribed || widget.isPro;

    // RTMP mode requires Pro
    if (_isRtmpMode) {
      if (!isPro) {
        showDialog(context: context, builder: (_) => const PaywallDialog());
        return;
      }
      if (_rtmpUrlController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.rtmpUrlRequired),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }

    // Save RTMP settings for iOS Broadcast Extension
    if (Platform.isIOS) {
      await RtmpSettingsService.saveSettings(
        mode: _isRtmpMode ? 'rtmp' : 'webrtc',
        url: _rtmpUrlController.text.trim(),
        key: _rtmpKeyController.text.trim(),
      );
    }

    // Trial notice for free users
    if (!isPro) {
      final prefs = await SharedPreferences.getInstance();
      final trialUsed = prefs.getBool('free_trial_used') ?? false;
      final limitText = trialUsed ? '30 seconds' : '2 minutes';
      _webrtc.freeTrialUsed = trialUsed;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Free Version: Streaming is limited to $limitText.',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
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
    }

    _webrtc.isLoading = true;
    setState(() {});

    try {
      // Configure iOS audio
      await MediaCaptureService.configureIOSAudio();

      final code = MediaCaptureService.generateCode();
      List<MediaStreamTrack> collectedTracks = [];
      _localStream = null;
      _cameraTrack = null;
      _cameraPreviewStream = null;

      // Capture Screen
      if (_shareScreen) {
        final screenStream = await MediaCaptureService.captureScreen();
        if (screenStream != null &&
            screenStream.getVideoTracks().isNotEmpty) {
          collectedTracks.add(screenStream.getVideoTracks()[0]);
        }
        await Future.delayed(
            const Duration(milliseconds: 800)); // iOS extension startup
      }

      // Capture Camera
      if (_shareCamera) {
        final camStream = await MediaCaptureService.captureCamera();
        if (camStream != null && camStream.getVideoTracks().isNotEmpty) {
          _cameraTrack = camStream.getVideoTracks()[0];
          _cameraPreviewStream = camStream;
          _cameraRenderer.srcObject = _cameraPreviewStream;
          collectedTracks.add(_cameraTrack!);
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Capture Microphone
      if (_shareMic) {
        final micStream =
            await MediaCaptureService.captureMic(initiallyMuted: _isMuted);
        if (micStream != null && micStream.getAudioTracks().isNotEmpty) {
          collectedTracks.add(micStream.getAudioTracks()[0]);
        }
      }

      if (collectedTracks.isEmpty) {
        throw Exception('Failed to acquire any media tracks.');
      }

      // Combine into master stream
      _localStream =
          await MediaCaptureService.assembleMasterStream(collectedTracks);
      _localRenderer.srcObject = _localStream;
      _isScreenSharing = _shareScreen;

      // Track ended handler
      for (var track in _localStream!.getTracks()) {
        track.onEnded = () {
          if (!_webrtc.isStopping) _stopBroadcast();
        };
      }

      // macOS RTMP mode (skips WebRTC)
      if (Platform.isMacOS && _isRtmpMode) {
        try {
          await const MethodChannel('com.eastlakestudio.castnow.pro/rtmp_macos')
              .invokeMethod('startRtmpBroadcast', {
            'url': _rtmpUrlController.text.trim(),
            'key': _rtmpKeyController.text.trim(),
          });
          if (mounted) {
            setState(() {
              _webrtc.isLoading = false;
              _webrtc.isConnected = true;
              _webrtc.peerId = 'RTMP (macOS)';
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _webrtc.isLoading = false);
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('RTMP Error: $e')));
          }
        }
        return;
      }

      // Start PeerJS connection
      await Future.delayed(const Duration(milliseconds: 1000));
      _webrtc.connect(
        code: code,
        localStream: _localStream!,
        isPro: isPro,
        initialFreeTrialUsed: _webrtc.freeTrialUsed,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Critical Error: $e')));
        setState(() => _webrtc.isLoading = false);
      }
    }
  }

  void _stopBroadcast() async {
    if (!mounted || _webrtc.isStopping) return;
    await _webrtc.persistAndStop();
    // macOS RTMP stop
    if (Platform.isMacOS && _isRtmpMode) {
      try {
        const MethodChannel('com.eastlakestudio.castnow.pro/rtmp_macos')
            .invokeMethod('stopRtmpBroadcast');
      } catch (_) {}
    }
    _localStream?.dispose();
    _localRenderer.srcObject = null;
    if (mounted) Navigator.pop(context);
  }

  void _showTimeUpDialog(String limitText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: const Text('Time Limit Reached',
            style: TextStyle(color: Colors.cyanAccent)),
        content: Text(
            'Free streaming is limited to $limitText.\nUpgrade to PRO to continue this broadcast.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _stopBroadcast();
            },
            child:
                const Text('STOP', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                      context: context,
                      builder: (_) => const PaywallDialog())
                  .then((_) {
                if (mounted &&
                    !context.read<SubscriptionService>().isSubscribed) {
                  _stopBroadcast();
                }
              });
            },
            child: const Text('UPGRADE TO PRO',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // === UI Builders ===

  Widget _buildScreenSharingPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Stack(
        children: [
          Center(
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
                          spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.screen_share_rounded,
                      color: Colors.cyanAccent, size: 48),
                ),
                const SizedBox(height: 20),
                GlassContainer(
                  blurSigma: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  borderRadius: 16,
                  child: const Text('Screen Mirroring Active',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(height: 6),
                Text('Sharing entire screen...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBar() {
    if (_webrtc.isConnected) return const SizedBox.shrink();
    return GlassContainer(
      blurSigma: 8,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: 20,
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
                TextSpan(text: 'Open '),
                TextSpan(
                    text: 'castnow.vercel.app',
                    style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline)),
                TextSpan(text: ' to receive'),
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

    // Layer 2: Frame-level cancel timer for Pro users
    if (isPro) {
      _webrtc.cancelTrialTimer();
    }

    // Source Selection View
    if (_webrtc.peerId == null && !_webrtc.isLoading) {
      return _buildSourceSelectionView();
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  // Preview area
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
                            ? _buildPreviewContent(isLandscape)
                            : Container(),
                      ),
                      if (_localStream != null)
                        _buildStatusOverlay(isPro),
                    ]),
                  ),
                  // Code display (portrait only)
                  if (!isLandscape && _webrtc.peerId != null)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: CodeDisplay(
                        peerId: _webrtc.peerId,
                        isConnected: _webrtc.isConnected,
                        receiverInfo: _webrtc.receiverInfo,
                      ),
                    ),
                  const SizedBox(height: 180),
                ],
              ),
            ),
            // Control bar
            if (_localStream != null)
              Positioned(
                bottom: 30,
                left: 16,
                right: 16,
                child: _buildControlBar(isPro, isLandscape),
              ),
            // Loading overlay
            if (_webrtc.isLoading)
              Container(
                  color: Colors.black54,
                  child:
                      const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelectionView() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [kPrimaryColor.withOpacity(0.05), Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: Colors.cyanAccent, size: 36),
                          const SizedBox(height: 12),
                          const Text('SELECT SOURCES',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2)),
                          const SizedBox(height: 6),
                          const Text(
                              'Select what to broadcast to the receiver',
                              style: TextStyle(
                                  color: kTextSecondary, fontSize: 13)),
                          const SizedBox(height: 24),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 400),
                            child: SourceSelector(
                              shareScreen: _shareScreen,
                              shareCamera: _shareCamera,
                              shareMic: _shareMic,
                              isRtmpMode: _isRtmpMode,
                              rtmpUrlController: _rtmpUrlController,
                              rtmpKeyController: _rtmpKeyController,
                              onScreenChanged: (val) => setState(() {
                                _shareScreen = val;
                                if (val) _shareCamera = false;
                              }),
                              onCameraChanged: (val) => setState(() {
                                _shareCamera = val;
                                if (val) _shareScreen = false;
                              }),
                              onMicChanged: (val) =>
                                  setState(() => _shareMic = val),
                              onRtmpChanged: (val) =>
                                  setState(() => _isRtmpMode = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: SizedBox(
                      width: 320,
                      child: GlassContainer(
                        blurSigma: 8,
                        showGradientBorder: false,
                        borderRadius: 24,
                        child: ElevatedButton(
                          onPressed: _startBroadcast,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 22),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text('START BROADCAST',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1.5)),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(bool isLandscape) {
    final hasBoth = _isScreenSharing && _shareCamera;

    if (!hasBoth) {
      return _isScreenSharing
          ? _buildScreenSharingPlaceholder()
          : RTCVideoView(_cameraRenderer, mirror: true);
    }

    return Flex(
      direction: isLandscape ? Axis.horizontal : Axis.vertical,
      children: [
        Expanded(child: _buildScreenSharingPlaceholder()),
        Container(
            width: isLandscape ? 1 : double.infinity,
            height: isLandscape ? double.infinity : 1,
            color: Colors.white10),
        Expanded(child: RTCVideoView(_cameraRenderer, mirror: true)),
      ],
    );
  }

  Widget _buildStatusOverlay(bool isPro) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.all(Radius.circular(20))),
            child: Row(children: [
              Icon(Icons.circle,
                  color: _webrtc.isConnected
                      ? Colors.green
                      : (_isScreenSharing ? Colors.blue : Colors.red),
                  size: 8),
              const SizedBox(width: 8),
              Text(
                  _webrtc.isConnected
                      ? 'CONNECTED'
                      : (_isScreenSharing ? 'SHARING' : 'ON AIR'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              // Layer 3: Only show timer for non-Pro users after receiver connects
              if (!isPro && _webrtc.isConnected) ...[
                const SizedBox(width: 8),
                Text(
                    '${(_webrtc.remainingSeconds ~/ 60)}:${(_webrtc.remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12)),
              ]
            ]),
          ),
          Container(
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(
                onPressed: _stopBroadcast,
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(bool isPro, bool isLandscape) {
    final controlBar = BroadcastControls(
      shareCamera: _shareCamera,
      isMuted: _isMuted,
      isRemoteMuted: _isRemoteMuted,
      onFlipCamera: _switchCamera,
      onToggleMute: _toggleMute,
      onToggleRemoteMute: _toggleRemoteMute,
      onStop: _stopBroadcast,
    );

    if (isLandscape) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_webrtc.peerId != null)
            Expanded(
                child: CodeDisplay(
              peerId: _webrtc.peerId,
              isConnected: _webrtc.isConnected,
              receiverInfo: _webrtc.receiverInfo,
            )),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isPro) ...[
                const Opacity(
                    opacity: 0.8,
                    child: Text('PRO EDITION',
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
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isPro) ...[
          const Opacity(
              opacity: 0.8,
              child: Text('PRO EDITION',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.cyanAccent,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Colors.cyanAccent, blurRadius: 8)
                      ]))),
          const SizedBox(height: 12),
        ],
        controlBar,
        const SizedBox(height: 12),
        _buildTipBar(),
      ],
    );
  }
}
