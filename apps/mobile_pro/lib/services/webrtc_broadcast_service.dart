import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service class encapsulating all PeerJS WebRTC broadcast lifecycle logic.
///
/// Manages Peer creation, signaling, reconnection, call handling, trial timers,
/// and subscription cleanup. Reports state changes via callbacks to separate
/// business logic from UI rendering.
class WebrtcBroadcastService {
  // --- Public State ---
  String? peerId;
  bool isConnected = false;
  bool isLoading = false;
  String? receiverInfo;
  int remainingSeconds = 0;
  bool freeTrialUsed = false;

  // --- Callbacks ---
  VoidCallback? onStateChanged;
  void Function(String message)? onShowSnackBar;
  void Function(String limitText)? onTimeUp;
  void Function(MediaStream remoteStream)? onRemoteAudioStream;

  // --- Private ---
  Peer? _peer;
  final List<StreamSubscription> _peerSubscriptions = [];
  final List<MediaConnection> _activeCalls = [];
  Timer? _limitTimer;
  bool _isStopping = false;
  bool _isDisposed = false;
  bool _isPro = false;

  bool get isActive => !_isDisposed;
  bool get isStopping => _isStopping;

  /// Connect to the PeerJS signaling server and start broadcasting.
  Future<void> connect({
    required String code,
    required MediaStream localStream,
    required bool isPro,
    required bool initialFreeTrialUsed,
  }) async {
    _isStopping = false;
    isLoading = true;
    _isPro = isPro;
    freeTrialUsed = initialFreeTrialUsed;
    isConnected = false;
    remainingSeconds = 0;
    _limitTimer?.cancel();
    _limitTimer = null;
    onStateChanged?.call();
    await _connectWithRetry(code, localStream, isPro, 0);
  }

  Future<void> _connectWithRetry(
    String code,
    MediaStream localStream,
    bool isPro,
    int attempt,
  ) async {
    if (attempt > 8) {
      isLoading = false;
      onStateChanged?.call();
      onShowSnackBar?.call(
          'Signal Server Unavailable. Please check your internet connection.');
      return;
    }

    try {
      // 1. Thorough Cleanup of previous instance
      if (_peer != null) {
        _clearPeerSubscriptions();
        final p = _peer;
        _peer = null;
        Future.delayed(Duration(milliseconds: 500 + (attempt * 1000)), () {
          try {
            p?.dispose();
          } catch (_) {}
        });
        await Future.delayed(Duration(milliseconds: 500 + (attempt * 1000)));
      }

      if (_isDisposed || _isStopping) return;

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
          },
        ),
      );

      // 2. Setup event listeners
      _peerSubscriptions.add(_peer!.on('open').listen(
        (id) {
          peerId = id;
          isLoading = false;
          onStateChanged?.call();
        },
        onError: (e) => debugPrint('❌ [PEER] Open Stream Error: $e'),
        cancelOnError: false,
      ));

      _peerSubscriptions.add(_peer!.on('disconnected').listen(
        (_) {
          if (!_isDisposed && _peer != null && !_peer!.destroyed && !_isStopping) {
            _peer!.reconnect();
          }
        },
        onError: (e) => debugPrint('❌ [PEER] Disconnect Stream Error: $e'),
      ));

      _peerSubscriptions.add(_peer!.on('close').listen(
        (_) {
          if (!_isDisposed && !_isStopping) {
            _connectWithRetry(code, localStream, isPro, 0);
          }
        },
        onError: (e) => debugPrint('❌ [PEER] Close Stream Error: $e'),
      ));

      _peerSubscriptions.add(_peer!.on('error').listen(
        (error) {
          if (_isStopping) return;
          final errStr = error.toString().toLowerCase();
          final shouldRetry = errStr.contains('failed host lookup') ||
              errStr.contains('socketexception') ||
              errStr.contains('unavailable-id') ||
              errStr.contains('invalid-id') ||
              errStr.contains('websocketchannelexception');
          if (shouldRetry) {
            Future.delayed(const Duration(seconds: 3), () {
              if (!_isDisposed && !_isStopping) {
                _connectWithRetry(code, localStream, isPro, attempt + 1);
              }
            });
          } else {
            isLoading = false;
            onStateChanged?.call();
          }
        },
        onError: (e) => debugPrint('❌ [PEER] Error Stream Exception: $e'),
      ));

      // 3. v9.1 Media-Only Handshake: Unified handler for 'Knock' and 'Intercom'
      _peerSubscriptions.add(_peer!.on('call').listen((dynamic incoming) {
        if (incoming is! MediaConnection) return;
        final remoteCall = incoming;

        // A. Identify 'Knock' (Using CVN ID format and not yet connected)
        if (remoteCall.peer.startsWith('cnv_') && !isConnected) {
          final parts = remoteCall.peer.split('_');
          if (parts.length >= 3) {
            receiverInfo = '${parts[1]} on ${parts[2]}';
            onStateChanged?.call();
          }

          // Flash Close and Recall to prevent peerdart crash
          Future.delayed(const Duration(milliseconds: 100), () {
            try {
              remoteCall.close();
            } catch (_) {}
          });

          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_peer != null && !_isDisposed) {
              final recall = _peer!.call(remoteCall.peer, localStream);
              _activeCalls.add(recall);
              _setupCallHandlers(recall);
              _startTrialTimer();
            }
          });
        } else {
          // B. Treat as Intercom / Standard Call
          _setupCallHandlers(remoteCall);
          remoteCall.answer(localStream);
        }
      }, onError: (e) => debugPrint('❌ [v9.1] Call Listener Error: $e')));
    } catch (e) {
      debugPrint('❌ [PEER] Critical Connection Exception: $e');
      if (!_isDisposed && !_isStopping) {
        Future.delayed(const Duration(seconds: 5),
            () => _connectWithRetry(code, localStream, isPro, attempt + 1));
      }
    }
  }

  void _startTrialTimer() {
    isConnected = true;
    onStateChanged?.call();
    if (!_isPro) {
      remainingSeconds = freeTrialUsed ? 30 : 120;
      _limitTimer?.cancel();
      _limitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        if (remainingSeconds > 0) {
          remainingSeconds--;
          onStateChanged?.call();
        } else {
          timer.cancel();
          _persistTrialUsed();
          onTimeUp?.call(freeTrialUsed ? '30 seconds' : '2 minutes');
        }
      });
    }
  }

  void _setupCallHandlers(MediaConnection call) {
    if (!_activeCalls.contains(call)) _activeCalls.add(call);

    _peerSubscriptions.add(call.on('stream').listen((remoteStream) {
      if (remoteStream.getAudioTracks().isNotEmpty && onRemoteAudioStream != null) {
        onRemoteAudioStream!(remoteStream);
      }
      isConnected = true;
      onStateChanged?.call();
    }, onError: (e) => debugPrint('❌ [PEER] Call Stream Error: $e')));

    _peerSubscriptions.add(call.on('close').listen((_) {
      _activeCalls.remove(call);
      if (_activeCalls.isEmpty) {
        isConnected = false;
        _limitTimer?.cancel();
        onStateChanged?.call();
      }
    }));
  }

  void _clearPeerSubscriptions() {
    for (var s in _peerSubscriptions) {
      s.cancel();
    }
    _peerSubscriptions.clear();
  }

  Future<void> _persistTrialUsed() async {
    if (!freeTrialUsed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('free_trial_used', true);
      freeTrialUsed = true;
    }
  }

  /// Persist trial state and stop broadcasting.
  /// Call this before disposal to save trial state.
  Future<void> persistAndStop() async {
    if (_isStopping) return;
    await _persistTrialUsed();
    _isStopping = true;

    // Explicitly close all active calls to signal the receivers
    for (var call in List.from(_activeCalls)) {
      try {
        call.close();
      } catch (_) {}
    }
    _activeCalls.clear();

    _clearPeerSubscriptions();
    final p = _peer;
    _peer = null;

    // Give time for 'close' packets to fly before destroying the peer
    Future.delayed(const Duration(milliseconds: 300), () {
      p?.dispose();
    });
  }

  /// Cancel the trial timer (called when Pro user is detected).
  void cancelTrialTimer() {
    _limitTimer?.cancel();
    _limitTimer = null;
  }

  /// Dispose all resources. Must be called when the screen is disposed.
  void dispose() {
    _isDisposed = true;
    _limitTimer?.cancel();
    _clearPeerSubscriptions();
    try {
      _peer?.dispose();
    } catch (_) {}
    _peer = null;
  }
}
