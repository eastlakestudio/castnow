import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class RtmpSettingsService {
  static const MethodChannel _channel = MethodChannel('castnow_rtmp_settings');

  static Future<bool> saveSettings({
    required String mode,
    required String url,
    required String key,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('saveSettings', {
        'mode': mode,
        'url': url,
        'key': key,
      });
      return result ?? false;
    } catch (e) {
      debugPrint("Failed to save RTMP settings: $e");
      return false;
    }
  }
}
