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
  bool _showDebug = true;
  
  // Intercom State
  MediaStream? _localMicStream;
  bool _isMicMuted = false;

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

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _pipRenderer.dispose();
    _localMicStream?.dispose();
    _peer?.dispose();
    super.dispose();
  }

  void _toggleMic() {
    if (_localMicStream == null) return;
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
      debug: LogLevel.All,
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

    _peer!.on("open").listen((id) async {
       setState(() => _peerStatus = "Ready (ID: $id)");
       debugPrint("✅ [PEER] Receive connection opened with ID: $id. Calling broadcaster: $code");

       // Capture microphone for talkback before initiating the call
       MediaStream? micStream;
       try {
         await Permission.microphone.request();
         micStream = await navigator.mediaDevices.getUserMedia({
           'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
           'video': false
         });
         _localMicStream = micStream;
         for (var t in _localMicStream!.getAudioTracks()) { t.enabled = !_isMicMuted; }
       } catch (e) {
         debugPrint("⚠️ [PEER] Failed to capture microphone: $e. Using dummy stream.");
         micStream = await createLocalMediaStream('remote_receiver_dummy');
       }

       // Initiate CALL directly to the broadcaster
       final call = _peer!.call(code, micStream);
       _setupCallHandlers(call);
    });

    _peer!.on("error").listen((err) {
      debugPrint("❌ [PEER] Global Error: $err");
      if (mounted) setState(() => _isConnecting = false);
    });
  }

  void _setupCallHandlers(MediaConnection call) {
    setState(() => _peerStatus = "Connecting...");

    try {
      final pc = call.peerConnection;
      pc?.onIceConnectionState = (state) {
        debugPrint("❄️ [ICE] Connection State: $state");
        if (mounted) setState(() => _iceState = state.toString().split('.').last);
      };
    } catch (e) {
      debugPrint("⚠️ [PEER] Could not attach ICE listener: $e");
    }

    call.on("stream").listen((s) async {
      debugPrint("🎥 [PEER] Stream received! Tracks: ${s.getVideoTracks().length}");
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
          _hasPip = true;
        } else {
          _hasPip = false;
        }
      }
    });

    call.on("close").listen((_) {
      debugPrint("⛔ [PEER] Call closed");
      if (mounted) {
        setState(() {
          _isConnected = false;
          _peerStatus = "Disconnected";
        });
      }
    });

    call.on("error").listen((err) {
      debugPrint("❌ [PEER] Call Error: $err");
      if (mounted) setState(() => _isConnecting = false);
    });
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
                        child: Container(
                          width: 110,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2)],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RTCVideoView(secondaryRenderer),
                        ),
                      ),
                    ),
                ],
              )
            else
              Builder(builder: (context) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                return Flex(
                  direction: isLandscape ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(child: RTCVideoView(mainRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)),
                    Container(width: isLandscape ? 1 : 0, height: isLandscape ? 0 : 1, color: Colors.white10),
                    Expanded(child: RTCVideoView(secondaryRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)),
                  ],
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
                    IconButton(
                      icon: Icon(_isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: _isMicMuted ? Colors.redAccent : Colors.white),
                      onPressed: _toggleMic,
                      style: IconButton.styleFrom(backgroundColor: _isMicMuted ? Colors.red.withOpacity(0.2) : Colors.black26),
                    ),
                  ],
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
      body: Padding(
        padding: const EdgeInsets.all(32.0),
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
            // PIN Input
            GestureDetector(
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
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
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
  }
}
