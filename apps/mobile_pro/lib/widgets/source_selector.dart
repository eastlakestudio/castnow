import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import 'glass_container.dart';

class SourceSelector extends StatelessWidget {
  final bool shareScreen;
  final bool shareCamera;
  final bool shareMic;
  final bool isRtmpMode;
  final TextEditingController rtmpUrlController;
  final TextEditingController rtmpKeyController;
  final Function(bool) onScreenChanged;
  final Function(bool) onCameraChanged;
  final Function(bool) onMicChanged;
  final Function(bool) onRtmpChanged;

  const SourceSelector({
    super.key,
    required this.shareScreen,
    required this.shareCamera,
    required this.shareMic,
    required this.isRtmpMode,
    required this.rtmpUrlController,
    required this.rtmpKeyController,
    required this.onScreenChanged,
    required this.onCameraChanged,
    required this.onMicChanged,
    required this.onRtmpChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSourceCard(
          icon: Icons.phone_android_rounded,
          title: 'Screen Mirror',
          subtitle: 'Broadcast your entire iOS screen',
          value: shareScreen,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            if (!val && !shareCamera) return;
            onScreenChanged(val);
            if (val) onCameraChanged(false);
          },
        ),
        _buildSourceCard(
          icon: Icons.videocam_rounded,
          title: 'Camera View',
          subtitle: 'Share high-quality camera stream',
          value: shareCamera,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            if (!val && !shareScreen) return;
            onCameraChanged(val);
            if (val) onScreenChanged(false);
          },
        ),
        _buildSourceCard(
          icon: Icons.mic_rounded,
          title: 'HD Microphone',
          subtitle: 'Capture crystal clear audio (Muted by default)',
          value: shareMic,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            onMicChanged(val);
          },
        ),
        _buildSourceCard(
          icon: Icons.rss_feed_rounded,
          title: 'RTMP Mode',
          subtitle: 'Broadcast to RTMP server (YouTube, Twitch, etc.)',
          value: isRtmpMode,
          onChanged: (val) {
            HapticFeedback.selectionClick();
            onRtmpChanged(val);
          },
        ),
        // RTMP 字段区域：始终预留空间
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isRtmpMode ? 140 : 0,
          child: isRtmpMode
              ? Column(
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: rtmpUrlController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _rtmpInputDecoration('RTMP URL', 'rtmp://your-server/live'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rtmpKeyController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _rtmpInputDecoration('Stream Key', 'Enter stream key'),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  InputDecoration _rtmpInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: GlassContainer(
          blurSigma: value ? 4 : 2,
          showGradientBorder: false,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 20,
          backgroundOpacity: value ? 0.08 : 0.02,
          borderOpacity: value ? 0.4 : 0.1,
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
                  Text(title,
                      style: TextStyle(color: value ? Colors.white : kTextSecondary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: value ? Colors.white70 : kTextSecondary.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
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
      ),
    );
  }
}
