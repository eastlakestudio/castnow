import 'package:flutter/material.dart';

class BroadcastControls extends StatelessWidget {
  final bool shareCamera;
  final bool isMuted;
  final bool isRemoteMuted;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRemoteMute;
  final VoidCallback onStop;

  const BroadcastControls({
    super.key,
    required this.shareCamera,
    required this.isMuted,
    required this.isRemoteMuted,
    required this.onFlipCamera,
    required this.onToggleMute,
    required this.onToggleRemoteMute,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white10),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shareCamera)
            _buildControl(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Flip',
              color: Colors.white,
              onTap: onFlipCamera,
            ),
          _buildControl(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: isMuted ? 'Unmute' : 'Mute',
            color: isMuted ? Colors.red : Colors.white,
            onTap: onToggleMute,
          ),
          _buildControl(
            icon: isRemoteMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: 'Talk',
            color: isRemoteMuted ? Colors.white24 : Colors.cyanAccent,
            onTap: onToggleRemoteMute,
          ),
          Container(
            height: 24, width: 1,
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          _buildControl(
            icon: Icons.stop_circle,
            label: 'Stop',
            color: Colors.redAccent,
            onTap: onStop,
          ),
        ],
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
              style: TextStyle(color: color.withOpacity(0.95), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.2),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
