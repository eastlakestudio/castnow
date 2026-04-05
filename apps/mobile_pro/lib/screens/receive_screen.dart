import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});
  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final TextEditingController _codeController = TextEditingController();
  Peer? _peer;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _pipRenderer = RTCVideoRenderer();
  bool _hasPip = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  CastNowLayoutMode _layoutMode = CastNowLayoutMode.pip;
  bool _isSwapped = false;
  
  // Status Monitoring
  String _peerStatus = "Initializing";
  String _iceState = "N/A";
  bool _showDebug = false; // Hide debug UI by default
  
  // Intercom & Playback State
  MediaStream? _localMicStream;
  bool _isMicMuted = true;
  bool _isPlaybackMuted = false;
  
  // Subscription Tracking
  final List<StreamSubscription> _peerSubscriptions = [];
  Timer? _connTimeout;

  void _clearPeerSubscriptions() {
    _connTimeout?.cancel();
    for (var s in _peerSubscriptions) { s.cancel(); }
    _peerSubscriptions.clear();
  }

  void _toggleLayout() {
    setState(() {
      _layoutMode = _layoutMode == CastNowLayoutMode.pip 
        ? CastNowLayoutMode.sideBySide 
        : CastNowLayoutMode.pip;
    });
  }

  void _toggleSwap() {
    setState(() {
      _isSwapped = !_isSwapped;
    });
  }

  void _togglePlaybackVolume() {
    setState(() {
      _isPlaybackMuted = !_isPlaybackMuted;
      
      // On iOS/Android natively, RTCVideoRenderer.muted does not stop the WebRTC C++ Audio Mixer. 
      // Furthermore, it throws an exception on remote tracks.
      // We must explicitly disable the incoming remote audio tracks.
      if (_remoteRenderer.srcObject != null) {
        for (var t in _remoteRenderer.srcObject!.getAudioTracks()) {
          t.enabled = !_isPlaybackMuted;
          Helper.setVolume(_isPlaybackMuted ? 0.0 : 1.0, t);
        }
      }
      if (_pipRenderer.srcObject != null) {
        for (var t in _pipRenderer.srcObject!.getAudioTracks()) {
          t.enabled = !_isPlaybackMuted;
          Helper.setVolume(_isPlaybackMuted ? 0.0 : 1.0, t);
        }
      }
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _pipRenderer.dispose();
    _localMicStream?.dispose();
    _clearPeerSubscriptions();
    final p = _peer;
    _peer = null;
    Future.delayed(const Duration(milliseconds: 500), () => p?.dispose());
    super.dispose();
  }

  void _toggleMic() {
    if (_localMicStream == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isMicMuted = !_isMicMuted;
      for (var track in _localMicStream!.getAudioTracks()) {
        track.enabled = !_isMicMuted;
      }
    });
  }

  void _join() {
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    setState(() => _isConnecting = true);
    _peer = Peer(options: PeerOptions(
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
          {'urls': 'stun:stun.tuna.tsinghua.edu.cn:3478'},
        ]
      }
    ));

    _clearPeerSubscriptions();
    
    _peerSubscriptions.add(_peer!.on("open").listen((id) async {
       if (!mounted) return;
       setState(() => _peerStatus = "Ready (ID: $id)");
       debugPrint("✅ [PEER] Receive connection opened with ID: $id. Calling broadcaster: $code");

       // Capture placeholder media tracks to "seed" the SDP offer with m-lines
       MediaStream? micStream;
       try {
         await Permission.microphone.request();
         // Request minimal video/audio to get the slots in SDP
         micStream = await navigator.mediaDevices.getUserMedia({
           'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
           'video': false
         });
         _localMicStream = micStream;
         
         // CRITICAL: Disable tracks immediately so we don't send local media
         for (var t in _localMicStream!.getAudioTracks()) { t.enabled = false; }
       } catch (e) {
         debugPrint("⚠️ [PEER] Failed to capture placeholder media: $e");
         // Fallback to minimal audio-only if video fails
         try {
           micStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
           for (var t in micStream.getAudioTracks()) { t.enabled = false; }
         } catch (_) {
           micStream = await createLocalMediaStream('remote_receiver_dummy');
         }
       }

       // Initiate CALL directly to the broadcaster
       if (mounted && _peer != null) {
         final targetId = code;
         debugPrint("📡 [PEER] Attempting to call: $targetId with placeholder stream");
         
         _connTimeout?.cancel();
         _connTimeout = Timer(const Duration(seconds: 20), () {
           if (mounted && _isConnecting && !_isConnected) {
             debugPrint("⏳ [PEER] Connection timeout reaching target: $targetId");
             setState(() {
               _isConnecting = false;
               _peerStatus = "Timeout - Check Code";
             });
             _clearPeerSubscriptions();
             final p = _peer;
             _peer = null;
             Future.delayed(const Duration(milliseconds: 500), () => p?.dispose());
           }
         });

         // Add a protective delay to ensure signaling server synchronization
         await Future.delayed(const Duration(milliseconds: 700));
         if (!mounted || _peer == null) return;

         final conn = _peer!.connect(targetId);
         
         _peerSubscriptions.add(conn.on("open").listen((_) {
            debugPrint("🤝 [PEER] DataChannel connected. Waiting for broadcaster to call us...");
         }));
         
         _peerSubscriptions.add(_peer!.on("call").listen((call) {
            debugPrint("📞 [PEER] Incoming call from Broadcaster! Answering with intercom mic...");
            _connTimeout?.cancel(); // Cancel timeout since we got the call
            call.answer(micStream);
            _setupCallHandlers(call);
         }));
       }
    }));

    _peerSubscriptions.add(_peer!.on("disconnected").listen((_) {
      debugPrint("🔄 [PEER] Signaling disconnected. Attempting silent reconnect...");
      if (mounted && _peer != null && !_peer!.destroyed) {
        _peer!.reconnect();
      }
    }));

    _peerSubscriptions.add(_peer!.on("close").listen((_) {
      debugPrint("⛔ [PEER] Peer connection closed.");
      if (mounted) setState(() => _isConnected = false);
    }));

    _peerSubscriptions.add(_peer!.on("error").listen((err) {
      debugPrint("❌ [PEER] Global Error: $err");
      if (mounted) setState(() => _isConnecting = false);
    }));
  }

  void _setupCallHandlers(MediaConnection call) {
    setState(() => _peerStatus = "Connecting...");

    try {
      final pc = call.peerConnection;
      if (pc?.iceConnectionState != null) {
        _iceState = pc!.iceConnectionState!.toString().split('.').last;
      }
      pc?.onIceConnectionState = (state) {
        debugPrint("❄️ [ICE] Connection: $state");
        if (mounted) setState(() => _iceState = state.toString().split('.').last);
      };
      pc?.onSignalingState = (state) {
        debugPrint("📡 [SIGNAL] State: $state");
      };
      pc?.onConnectionState = (state) {
        debugPrint("🌐 [NET] State: $state");
      };
    } catch (e) {
      debugPrint("⚠️ [PEER] Could not attach state listeners: $e");
    }

    _peerSubscriptions.add(call.on("stream").listen((s) async {
      if (!mounted) return;
      _connTimeout?.cancel();
      debugPrint("🎥 [PEER] Stream received! Total Video: ${s.getVideoTracks().length}, Audio: ${s.getAudioTracks().length}");
      for (var t in s.getVideoTracks()) { debugPrint("   -> 🎬 Video Track: ${t.id} (enabled: ${t.enabled})"); }
      for (var t in s.getAudioTracks()) { debugPrint("   -> 🎤 Audio Track: ${t.id} (enabled: ${t.enabled})"); }
      
      // Route audio to speakerphone natively (fixes iOS earpiece issue)
      if (s.getAudioTracks().isNotEmpty) {
        Helper.setSpeakerphoneOn(true);
      }

      if (mounted) {
        setState(() {
          _peerStatus = "Streaming";
          _isConnected = true;
          _isConnecting = false;
        });
        _remoteRenderer.srcObject = s;
        
        if (s.getVideoTracks().length >= 2) {
          MediaStream pipStream = await createLocalMediaStream('remote_pip');
          pipStream.addTrack(s.getVideoTracks()[1]);
          _pipRenderer.srcObject = pipStream;
          if (mounted) {
            setState(() {
              _hasPip = true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasPip = false;
            });
          }
        }
      }
    }));

    _peerSubscriptions.add(call.on("close").listen((_) {
      debugPrint("⛔ [PEER] Call closed");
      if (mounted) {
        setState(() {
          _isConnected = false;
          _peerStatus = "Disconnected";
        });
      }
    }));

    _peerSubscriptions.add(call.on("error").listen((err) {
      debugPrint("❌ [PEER] Call Error: $err");
      _connTimeout?.cancel();
      if (mounted) setState(() => _isConnecting = false);
    }));
  }

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
    _pipRenderer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      final mainRenderer = _isSwapped ? _pipRenderer : _remoteRenderer;
      final secondaryRenderer = _isSwapped ? _remoteRenderer : _pipRenderer;

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video Layout
            if (!_hasPip || _layoutMode == CastNowLayoutMode.pip)
              Stack(
                children: [
                  RTCVideoView(mainRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                  if (_hasPip)
                    Positioned(
                      right: 20,
                      bottom: 40,
                      child: GestureDetector(
                        onTap: _toggleSwap,
                        onPanUpdate: (details) {
                          // TODO: Implement smooth drag if needed, 
                          // but for now, swap on tap is the primary goal
                        },
                        child: ValueListenableBuilder<RTCVideoValue>(
                          valueListenable: secondaryRenderer,
                          builder: (context, value, child) {
                            final aspect = value.width > 0 && value.height > 0 
                                ? value.width / value.height 
                                : 9 / 16;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AspectRatio(
                                aspectRatio: aspect,
                                child: RTCVideoView(secondaryRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                              ),
                            );
                          }
                        ),
                      ),
                    ),
                ],
              )
            else
              Builder(builder: (context) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                return Container(
                  color: Colors.black,
                  child: Flex(
                    direction: isLandscape ? Axis.horizontal : Axis.vertical,
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RTCVideoView(mainRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RTCVideoView(secondaryRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Top Bar
            Positioned(
              top: 40, 
              left: 16, 
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white), 
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: Colors.black26),
                  ),
                  const Spacer(),
                  if (_hasPip) ...[
                    IconButton(
                      icon: Icon(_layoutMode == CastNowLayoutMode.pip ? Icons.dashboard_outlined : Icons.view_quilt_outlined, color: Colors.white),
                      onPressed: _toggleLayout,
                      style: IconButton.styleFrom(backgroundColor: Colors.black26),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                      onPressed: _toggleSwap,
                      style: IconButton.styleFrom(backgroundColor: Colors.black26),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Mic button is always visible unconditionally
                  IconButton(
                    icon: Icon(_isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: _isMicMuted ? Colors.redAccent : Colors.white),
                    onPressed: _toggleMic,
                    style: IconButton.styleFrom(backgroundColor: _isMicMuted ? Colors.red.withOpacity(0.2) : Colors.black26),
                  ),
                  const SizedBox(width: 8),
                  // Playback Volume Mute toggle
                  IconButton(
                    icon: Icon(_isPlaybackMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: _isPlaybackMuted ? Colors.amber : Colors.white),
                    onPressed: _togglePlaybackVolume,
                    style: IconButton.styleFrom(backgroundColor: _isPlaybackMuted ? Colors.amber.withOpacity(0.2) : Colors.black26),
                  ),
                ],
              ),
            ),

            // Diagnostic Overlay
            if (_showDebug)
              Positioned(
                bottom: 20,
                left: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _showDebug = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _iceState == "failed" ? Colors.redAccent : Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text("STATUS: ", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                            Text(_peerStatus.toUpperCase(), style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text("ICE: ", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                            Text(_iceState.toUpperCase(), style: TextStyle(color: _iceState == "failed" ? Colors.redAccent : Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
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
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Join Stream"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Builder(builder: (context) {
          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

          final pinBoxes = GestureDetector(
            onTap: () {
              // Focus hidden textfield
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                 // Hidden TextField to capture input
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _codeController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                // Visual PIN Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final char = _codeController.text.length > index ? _codeController.text[index] : "";
                    final bool isFocused = _codeController.text.length == index;
                    
                    return Container(
                      width: 48,
                      height: 64,
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFocused ? kPrimaryColor : Colors.white10,
                          width: 2,
                        ),
                        boxShadow: isFocused ? [
                          BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 10)
                        ] : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );

          final connectButton = SizedBox(
            width: isLandscape ? 200 : double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _join,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
              ),
              child: _isConnecting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                : const Text("CONNECT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "ACCESS CODE",
                    style: TextStyle(
                      color: kTextSecondary,
                      letterSpacing: 4,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  if (isLandscape)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: pinBoxes),
                        const SizedBox(width: 48),
                        connectButton,
                      ],
                    )
                  else
                    Column(
                      children: [
                        pinBoxes,
                        const SizedBox(height: 48),
                        connectButton,
                      ],
                    ),
                    
                  const SizedBox(height: 24),
                  Text(
                    "Ask the broadcaster for the 6-digit key",
                    style: TextStyle(color: kTextSecondary.withOpacity(0.5), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
