import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/constants.dart';

class ReceiveScreen extends StatefulWidget {
  final String? pairCode;
  const ReceiveScreen({super.key, this.pairCode});

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
  bool _isSwapped = false;
  bool _isMicMuted = true;
  bool _isPlaybackMuted = false;
  String? _broadcasterInfo;
  final List<StreamSubscription> _peerSubscriptions = [];
  MediaStream? _localMicStream;

  @override
  void initState() {
    super.initState();
    if (widget.pairCode != null) {
      _codeController.text = widget.pairCode!;
    }
    _remoteRenderer.initialize();
    _pipRenderer.initialize();
  }

  @override
  void dispose() {
    _stopAll();
    _remoteRenderer.dispose();
    _pipRenderer.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _stopAll() {
    for (var s in _peerSubscriptions) { s.cancel(); }
    _peerSubscriptions.clear();
    _localMicStream?.dispose();
    _peer?.dispose();
    _peer = null;
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceDocs = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceDocs.iosInfo;
      return {'model': 'CastNow', 'os': 'iOS ${iosInfo.systemVersion}'};
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceDocs.androidInfo;
      return {'model': 'CastNow', 'os': 'Android ${androidInfo.version.release}'};
    }
    return {'model': 'Mobile', 'os': 'Unknown'};
  }

  Future<void> _join() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    // 1. 生成符合规范的 Rich ID (无空格，单下划线)
    final info = await _getDeviceInfo();
    final model = (info['model'] ?? "Device").replaceAll(RegExp(r'\s+'), '');
    final os = (info['os'] ?? "iOS").replaceAll(RegExp(r'\s+'), '');
    final randomPart = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    // 使用 cnv_ 前缀和单下划线，避免 PeerJS 报错
    final richId = "cnv_${model}_${os}_$randomPart";

    final code = _codeController.text.trim();
    if (code.length != 6) {
      if (mounted) setState(() => _isConnecting = false);
      return;
    }

    debugPrint("🚀 [v9.1] Registering with Identity: $richId");

    // 2. 初始化 Peer
    _peer = Peer(id: richId, options: PeerOptions(
      host: '0.peerjs.com',
      port: 443,
      secure: true,
      debug: LogLevel.All
    ));

    // 3. 监听生命周期
    _peerSubscriptions.add(_peer!.on("open").listen((id) async {
      debugPrint("✅ [v9.1] Connected as: $id. Signaling: $code");
      
      try {
        await Permission.microphone.request();
        _localMicStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
        for (var t in _localMicStream!.getAudioTracks()) { t.enabled = false; }
        
        // 发起“敲门呼叫”
        _peer!.call(code, _localMicStream!);
      } catch (e) {
        debugPrint("⚠️ Mic error: $e");
      }
    }));

    _peerSubscriptions.add(_peer!.on("call").listen((call) {
      debugPrint("📞 [v9.1] Incoming recall from Broadcaster. Answering...");
      _setupCallHandlers(call);
      call.answer(_localMicStream!);
    }));

    _peerSubscriptions.add(_peer!.on("error").listen((err) {
      debugPrint("❌ [v9.1] Peer error: $err");
      if (mounted) setState(() => _isConnecting = false);
    }));

    _peerSubscriptions.add(_peer!.on("close").listen((data) {
      if (mounted && _isConnected) Navigator.pop(context);
    }));
  }

  void _setupCallHandlers(MediaConnection call) {
    // Extract Broadcaster Metadata if available
    if (call.metadata != null && mounted) {
      setState(() {
        if (call.metadata is Map) {
          final device = call.metadata['device'] ?? "Broadcaster";
          final os = call.metadata['os'] ?? "";
          _broadcasterInfo = os.isNotEmpty ? "$device on $os" : device;
        } else {
          _broadcasterInfo = call.metadata.toString();
        }
      });
    }

    _peerSubscriptions.add(call.on("stream").listen((s) {
      if (!mounted) return;
      debugPrint("🎥 [v9.1] Received Remote Stream - Video=${s.getVideoTracks().length}");

      // 🎥 Robust Auto-Exit: Only exit when ALL tracks are no longer live
      void checkExit() {
        final liveTracks = s.getTracks().where((t) => t.state != null && t.state!.index == 0).toList(); 
        debugPrint("🎬 [v9.1] Checking exit status. Live total tracks: ${liveTracks.length}");
        if (liveTracks.isEmpty) {
          debugPrint("📺 [v9.1] No more live video tracks. Exiting...");
          if (mounted) Navigator.pop(context);
        }
      }

      for (final track in s.getTracks()) {
        track.onEnded = () {
          debugPrint("📺 [v9.1] A native track ended (${track.kind}). Checking total status...");
          // Small delay to let the state update
          Future.delayed(const Duration(milliseconds: 200), () => checkExit());
        };
      }

      _updateRenderers(s);
    }));

    // Signaling-level fallback (works if library doesn't crash)
    _peerSubscriptions.add(call.on("close").listen((_) {
      debugPrint("⛔ [v9.1] Signaling call closed. Exiting...");
      if (mounted) Navigator.pop(context);
    }));
  }

  Future<void> _updateRenderers(MediaStream s) async {
    final tracks = s.getVideoTracks();
    debugPrint("🎬 [v9.1] Updating renderers. Total tracks: ${tracks.length}");
    
    // 1. Double-Kick Logic: Force native layer re-attach
    for (var track in tracks) {
      track.enabled = false;
      await Future.delayed(const Duration(milliseconds: 10));
      track.enabled = true;
    }

    if (mounted) {
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _hasPip = tracks.length > 1;
        _remoteRenderer.srcObject = s;
      });
    }

    if (_hasPip) {
      try {
        final pipStream = await createLocalMediaStream('pip_stream');
        pipStream.addTrack(tracks[1]);
        if (mounted) {
          setState(() {
            _pipRenderer.srcObject = pipStream;
            _pipRenderer.muted = true; 
          });
        }
      } catch (e) {
        debugPrint("⚠️ Failed to create PiP stream: $e");
      }
    }

    // 2. Tiered Refresh: 100ms for fast start, 500ms as fail-safe
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() {});
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {});
    });
  }

  void _toggleMic() {
    if (_localMicStream == null) return;
    setState(() {
      _isMicMuted = !_isMicMuted;
      for (var t in _localMicStream!.getAudioTracks()) { t.enabled = !_isMicMuted; }
    });
  }

  void _togglePlayback() {
    setState(() {
      _isPlaybackMuted = !_isPlaybackMuted;
      _remoteRenderer.muted = _isPlaybackMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            RTCVideoView(_isSwapped && _hasPip ? _pipRenderer : _remoteRenderer, 
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
            if (_hasPip)
              Positioned(
                right: 20, bottom: 40,
                child: GestureDetector(
                  onTap: () => setState(() => _isSwapped = !_isSwapped),
                  child: Container(
                    width: 120, height: 160,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(!_isSwapped ? _pipRenderer : _remoteRenderer, 
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              ),
            Positioned(
              top: 40, left: 16, right: 16,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), 
                    onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_broadcasterInfo ?? "CONNECTED", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: Icon(_isMicMuted ? Icons.mic_off : Icons.mic, color: _isMicMuted ? Colors.red : Colors.green),
                    onPressed: _toggleMic),
                  IconButton(icon: Icon(_isPlaybackMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                    onPressed: _togglePlayback),
                ],
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
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Text("ACCESS CODE", 
                  style: TextStyle(color: kTextSecondary, letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                
                GestureDetector(
                  onTap: () {},
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _codeController, 
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 6, 
                          onChanged: (v) => setState(() {}),
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
                ),
                
                const SizedBox(height: 48),
                
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    onPressed: _join,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor, 
                      foregroundColor: Colors.black, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: _isConnecting 
                        ? const CircularProgressIndicator(color: Colors.black) 
                        : const Text("CONNECT", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 24),
                Text("Ask broadcaster for key", style: TextStyle(color: kTextSecondary.withOpacity(0.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
