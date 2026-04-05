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
  MediaStream? _totalRemoteStream; 
  
  MediaStream? _localMicStream;
  bool _isMicMuted = true;
  bool _isPlaybackMuted = false;
  
  final List<StreamSubscription> _peerSubscriptions = [];
  Timer? _connTimeout;

  void _clearPeerSubscriptions() {
    _connTimeout?.cancel();
    for (var s in _peerSubscriptions) { s.cancel(); }
    _peerSubscriptions.clear();
  }

  void _toggleLayout() {
    setState(() => _layoutMode = _layoutMode == CastNowLayoutMode.pip ? CastNowLayoutMode.sideBySide : CastNowLayoutMode.pip);
  }

  void _toggleSwap() {
    setState(() => _isSwapped = !_isSwapped);
  }

  void _togglePlaybackVolume() {
    setState(() {
      _isPlaybackMuted = !_isPlaybackMuted;
      if (_totalRemoteStream != null) {
        for (var t in _totalRemoteStream!.getAudioTracks()) {
          t.enabled = !_isPlaybackMuted;
          Helper.setVolume(_isPlaybackMuted ? 0.0 : 1.0, t);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
    _pipRenderer.initialize();
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
      for (var track in _localMicStream!.getAudioTracks()) { track.enabled = !_isMicMuted; }
    });
  }

  void _join() {
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    setState(() => _isConnecting = true);
    _peer = Peer(options: PeerOptions(
      host: '0.peerjs.com', port: 443, path: '/', secure: true,
      debug: LogLevel.Errors,
      config: {
        'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}, {'urls': 'stun:stun.miwifi.com:3478'}],
        'sdpSemantics': 'unified-plan'
      }
    ));

    _clearPeerSubscriptions();
    _peerSubscriptions.add(_peer!.on("open").listen((id) async {
       if (!mounted) return;
       debugPrint("✅ [PEER] Receive connection opened with ID: $id. Connecting to: $code");
       try {
         await Permission.microphone.request();
         final micStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
         if (mounted) {
           setState(() {
             _localMicStream = micStream;
             _isMicMuted = true;
             for (var t in _localMicStream!.getAudioTracks()) { t.enabled = false; }
           });
         }
       } catch (_) {
         _localMicStream = await createLocalMediaStream('dm_mic');
       }

       if (mounted && _peer != null) {
          _connTimeout?.cancel();
          _connTimeout = Timer(const Duration(seconds: 20), () {
            if (mounted && _isConnecting && !_isConnected) setState(() => _isConnecting = false);
          });
          
          // 1. Establish intercom call (audio only) - Web will use this to call us back with video
          final call = _peer!.call(code, _localMicStream!);
          _setupCallHandlers(call);
       }
    }));

    // Handle incoming video call from Web broadcaster
    _peerSubscriptions.add(_peer!.on("call").listen((call) {
      debugPrint("📡 [PEER] Received incoming video call from: ${call.peer}");
      _setupCallHandlers(call);
      call.answer(_localMicStream!); // Answer with mic for bi-directional if needed
    }));

    _peerSubscriptions.add(_peer!.on("error").listen((err) { 
      debugPrint("❌ [PEER] Peer Error: $err");
      if (mounted) setState(() => _isConnecting = false); 
    }));
  }

  void _setupCallHandlers(MediaConnection call) {
    if (!mounted) return;
    debugPrint("📞 [PEER] Call Handlers Initialized for: ${call.peer}");

    try {
      final pc = call.peerConnection;
      pc?.onIceConnectionState = (state) {
        debugPrint("❄️ [ICE] Connection State: $state");
      };
      
      pc?.onTrack = (event) {
        if (!mounted) return;
        debugPrint("📡 [TRACK] Incoming ${event.track.kind} track: ${event.track.id}");
        if (event.track.kind == 'video') {
          final stream = (event.streams.isNotEmpty) ? event.streams.first : _totalRemoteStream;
          if (stream != null) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                debugPrint("🔄 [PEER] Refreshing renderers for new track (Count: ${stream.getVideoTracks().length})");
                _updateRenderers(stream);
              }
            });
          }
        }
      };
    } catch (e) {
      debugPrint("⚠️ [PEER] RTCPeerConnection error: $e");
    }

    _peerSubscriptions.add(call.on("stream").listen((s) async {
      if (!mounted) return;
      _connTimeout?.cancel();
      debugPrint("🎥 [STREAM] Initial Snapshot - Audio=${s.getAudioTracks().length}, Video=${s.getVideoTracks().length}");
      
      // v4 Priority Check: Don't let a 1-track snapshot override a stable 2-track stream
      if (_totalRemoteStream != null && _totalRemoteStream!.getVideoTracks().length > s.getVideoTracks().length) {
        debugPrint("⚠️ [RENDER] Ignoring lower-priority snapshot (New: ${s.getVideoTracks().length} vs Old: ${_totalRemoteStream!.getVideoTracks().length})");
        return;
      }
      
      _totalRemoteStream = s;
      if (s.getAudioTracks().isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () => Helper.setSpeakerphoneOn(true));
      }
      _updateRenderers(s);
    }));

    _peerSubscriptions.add(call.on("close").listen((_) { 
      debugPrint("⛔ [PEER] Session closed");
      if (mounted) setState(() => _isConnected = false); 
    }));

    _peerSubscriptions.add(call.on("error").listen((err) { 
      debugPrint("❌ [PEER] Connection error: $err");
      if (mounted) setState(() => _isConnecting = false); 
    }));
  }

  void _updateRenderers(MediaStream s) async {
    if (!mounted) return;
    final vt = s.getVideoTracks();
    if (vt.isEmpty) return;

    // v4 Priority Check: Don't let a 1-track stream override a stable 2-track stream
    if (_totalRemoteStream != null && _totalRemoteStream!.getVideoTracks().length > vt.length) {
      debugPrint("⚠️ [RENDER] Ignoring lower-priority stream (New: ${vt.length} vs Old: ${_totalRemoteStream!.getVideoTracks().length})");
      return;
    }

    setState(() { 
      _isConnected = true; 
      _isConnecting = false; 
      _totalRemoteStream = s; 
    });

    // Main Renderer
    MediaStream mv = await createLocalMediaStream('mv');
    mv.addTrack(vt[0]);
    for (var at in s.getAudioTracks()) { mv.addTrack(at); }
    _remoteRenderer.srcObject = mv;

    // PiP Renderer - Auto detects if 2nd track surfaced
    if (vt.length >= 2) {
      debugPrint("📱 [RENDER] Multi-track detected! Binding PiP to track: ${vt[1].id}");
      MediaStream pv = await createLocalMediaStream('pv');
      pv.addTrack(vt[1]);
      _pipRenderer.srcObject = pv;
      if (!_hasPip) setState(() => _hasPip = true);
    } else {
      if (_hasPip) setState(() => _hasPip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
// ... existing build logic ...
      final mainR = _isSwapped ? _pipRenderer : _remoteRenderer;
      final secR = _isSwapped ? _remoteRenderer : _pipRenderer;

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (!_hasPip || _layoutMode == CastNowLayoutMode.pip)
              Stack(
                children: [
                  RTCVideoView(mainR, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                  if (_hasPip)
                    Positioned(
                      right: 20, bottom: 40,
                      child: GestureDetector(
                        onTap: _toggleSwap,
                        child: ValueListenableBuilder<RTCVideoValue>(
                          valueListenable: secR,
                          builder: (context, val, child) {
                            final aspect = val.width > 0 ? val.width / val.height : 9/16;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: const Offset(0, 10))],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AspectRatio(aspectRatio: aspect, child: RTCVideoView(secR, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
                            );
                          }
                        ),
                      ),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: RTCVideoView(mainR, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)),
                  Expanded(child: RTCVideoView(secR, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)),
                ],
              ),
            Positioned(
              top: 40, left: 16, right: 16,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  if (_hasPip) ...[
                    IconButton(
                      icon: Icon(_layoutMode == CastNowLayoutMode.pip ? Icons.dashboard_outlined : Icons.view_quilt_outlined, color: Colors.white),
                      onPressed: _toggleLayout,
                    ),
                    IconButton(icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white), onPressed: _toggleSwap),
                  ],
                  IconButton(icon: Icon(_isMicMuted ? Icons.mic_off : Icons.mic, color: _isMicMuted ? Colors.red : Colors.greenAccent), onPressed: _toggleMic, style: IconButton.styleFrom(backgroundColor: Colors.black26)),
                  IconButton(icon: Icon(_isPlaybackMuted ? Icons.volume_off : Icons.volume_up, color: _isPlaybackMuted ? Colors.amber : Colors.white), onPressed: _togglePlaybackVolume, style: IconButton.styleFrom(backgroundColor: Colors.black26)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("Join Stream"), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: Builder(builder: (context) {
          final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
          
          final pinInput = GestureDetector(
            onTap: () {},
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _codeController, autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6, onChanged: (v) => setState(() {}),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final char = _codeController.text.length > i ? _codeController.text[i] : "";
                    final active = _codeController.text.length == i;
                    return Container(
                      width: 48, height: 64,
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: active ? kPrimaryColor : Colors.white10, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(char, style: const TextStyle(color: kPrimaryColor, fontSize: 28, fontWeight: FontWeight.bold)),
                    );
                  }),
                ),
              ],
            ),
          );

          final btn = SizedBox(
            width: isLand ? 180 : double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: _join,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _isConnecting ? const CircularProgressIndicator(color: Colors.black) : const Text("CONNECT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text("ACCESS CODE", style: TextStyle(color: kTextSecondary, letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  if (isLand) Row(mainAxisAlignment: MainAxisAlignment.center, children: [Expanded(child: pinInput), const SizedBox(width: 32), btn])
                  else Column(children: [pinInput, const SizedBox(height: 48), btn]),
                  const SizedBox(height: 24),
                  Text("Ask broadcaster for key", style: TextStyle(color: kTextSecondary.withOpacity(0.5))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Ensure toggle icons are restored in the Stack controls
// (I will update the icon buttons separately to be precise)

