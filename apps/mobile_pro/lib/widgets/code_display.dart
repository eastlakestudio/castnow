import 'package:flutter/material.dart';
import '../core/constants.dart';

class CodeDisplay extends StatelessWidget {
  final String? peerId;
  final bool isConnected;
  final String? receiverInfo;

  const CodeDisplay({
    super.key,
    this.peerId,
    this.isConnected = false,
    this.receiverInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (peerId == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('SHARING ACCESS KEY',
            style: TextStyle(color: kTextSecondary, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: peerId!
                .split('')
                .map((char) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                      ),
                      child: Text(char, style: const TextStyle(color: kPrimaryColor, fontSize: 32, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
        ),
        if (isConnected && receiverInfo != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.devices_rounded, color: Colors.green, size: 14),
                const SizedBox(width: 8),
                Text('Receiver: $receiverInfo',
                    style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
        ] else if (!isConnected)
          const SizedBox(height: 12),
      ],
    );
  }
}
