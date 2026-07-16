import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service class encapsulating media capture logic for CastNow broadcast.
///
/// Provides static methods for capturing screen, camera, microphone streams
/// and assembling them into the final master stream used for P2P broadcasting.
class MediaCaptureService {
  /// Configure iOS audio for broadcast mode (playAndRecord with defaultToSpeaker).
  static Future<void> configureIOSAudio() async {
    if (Platform.isIOS) {
      await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
        appleAudioCategory: AppleAudioCategory.playAndRecord,
        appleAudioCategoryOptions: {
          AppleAudioCategoryOption.allowBluetooth,
          AppleAudioCategoryOption.defaultToSpeaker,
          AppleAudioCategoryOption.mixWithOthers,
        },
        appleAudioMode: AppleAudioMode.videoChat,
      ));
    }
  }

  /// Request necessary permissions for camera (non-web, non-macOS).
  static Future<void> requestCameraPermission() async {
    if (!kIsWeb && !Platform.isMacOS) {
      await Permission.camera.request();
    }
  }

  /// Request necessary permissions for microphone (non-web, non-macOS).
  static Future<void> requestMicPermission() async {
    if (!kIsWeb && !Platform.isMacOS) {
      await Permission.microphone.request();
    }
  }

  /// Capture the device screen via Broadcast Extension (iOS) or standard API.
  /// Returns the screen [MediaStream], or null on failure.
  static Future<MediaStream?> captureScreen() async {
    try {
      if (Platform.isIOS) {
        return await navigator.mediaDevices.getDisplayMedia({
          'video': {
            'deviceId': 'broadcast',
            'frameRate': 24,
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
          'audio': false,
        });
      } else {
        return await navigator.mediaDevices
            .getDisplayMedia({'video': true, 'audio': false});
      }
    } catch (e) {
      debugPrint('⚠️ [BROADCAST] Screen capture failed: $e');
      return null;
    }
  }

  /// Capture the front-facing camera as a [MediaStream].
  /// Returns the camera stream, or null on failure.
  static Future<MediaStream?> captureCamera() async {
    try {
      await requestCameraPermission();
      return await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
          'frameRate': 24,
        },
      });
    } catch (e) {
      debugPrint('⚠️ [BROADCAST] Camera capture failed: $e');
      return null;
    }
  }

  /// Capture the microphone as a [MediaStream] with echo cancellation.
  /// Returns the mic stream, or null on failure.
  static Future<MediaStream?> captureMic({bool initiallyMuted = true}) async {
    try {
      await requestMicPermission();
      final micStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      if (micStream.getAudioTracks().isNotEmpty && initiallyMuted) {
        micStream.getAudioTracks()[0].enabled = false;
      }
      return micStream;
    } catch (e) {
      debugPrint('⚠️ [BROADCAST] Mic capture failed: $e');
      return null;
    }
  }

  /// Assemble a list of [MediaStreamTrack]s into a single master [MediaStream].
  static Future<MediaStream> assembleMasterStream(
      List<MediaStreamTrack> tracks) async {
    final stream = await createLocalMediaStream('master_stream');
    for (var track in tracks) {
      await stream.addTrack(track);
    }
    return stream;
  }

  /// Switch the camera between front and rear facing.
  static Future<void> switchCamera(MediaStreamTrack cameraTrack) async {
    try {
      await Helper.switchCamera(cameraTrack);
    } catch (e) {
      debugPrint('❌ Switch Camera Error: $e');
    }
  }

  /// Generate a random 6-digit pairing code.
  static String generateCode() {
    final rng = math.Random();
    return (100000 + rng.nextInt(900000)).toString();
  }
}
