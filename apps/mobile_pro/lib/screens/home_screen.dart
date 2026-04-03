import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'broadcast_screen.dart';
import 'receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final bool _isPro = true;

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      final mode = url.startsWith('mailto:') 
          ? LaunchMode.platformDefault 
          : LaunchMode.externalApplication;
          
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode);
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content,
      {String? url, String? urlText}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title,
            style: const TextStyle(
                color: kPrimaryColor, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child:
                SelectableText(content, style: const TextStyle(color: kTextSecondary))),
        actions: [
          if (url != null)
            TextButton(
              onPressed: () => _launchURL(url),
              child: Text(urlText ?? "OPEN",
                  style: const TextStyle(
                      color: kPrimaryColor, fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE",
                style: TextStyle(
                    color: kPrimaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    Widget brandSection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text("P2P SECURE",
                  style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isLandscape ? 60 : 80,
              height: isLandscape ? 60 : 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF020617)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(isLandscape ? 18 : 24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                      color: kPrimaryColor.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Icon(Icons.bolt_rounded,
                  color: kPrimaryColor, size: isLandscape ? 36 : 48),
            ),
            const Positioned(
              top: -2,
              left: -2,
              child: Text(
                "PRO",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyanAccent,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.cyanAccent, blurRadius: 4),
                    Shadow(color: Colors.cyanAccent, blurRadius: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isLandscape ? 8 : 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'Cast'),
              TextSpan(text: 'Now', style: TextStyle(color: kPrimaryColor)),
              TextSpan(text: ' Pro', style: TextStyle(fontSize: 24, color: Colors.cyanAccent)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              const Text(
                "Receive on: ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => _launchURL("https://castnow.vercel.app"),
                child: const Text(
                  "castnow.vercel.app",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget actionsSection = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            context,
            title: "Broadcast",
            subtitle: "Share camera or screen",
            icon: Icons.wifi_tethering,
            color: kPrimaryColor,
            textColor: Colors.black,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BroadcastScreen(isPro: _isPro))),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            context,
            title: "Receive",
            subtitle: "Watch a stream",
            icon: Icons.download_rounded,
            color: kSurfaceColor,
            textColor: kTextPrimary,
            isOutlined: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveScreen())),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final horizontalPadding = isWide ? 40.0 : 24.0;
            
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        isWide 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: brandSection),
                                Container(width: 1, height: 180, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 40)),
                                Expanded(child: actionsSection),
                              ],
                            )
                          : Column(
                              children: [
                                brandSection,
                                const SizedBox(height: 48),
                                actionsSection,
                              ],
                            ),
                        const SizedBox(height: 48),
                        _buildFooter(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required Color textColor,
      bool isOutlined = false,
      required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Material(
        color: isOutlined ? Colors.transparent : color,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isOutlined
                ? BorderSide(color: Colors.white.withOpacity(0.1))
                : BorderSide.none),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isOutlined ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: isOutlined ? kPrimaryColor : Colors.black87, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: isOutlined ? kTextPrimary : textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: isOutlined ? kTextSecondary : textColor.withOpacity(0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: isOutlined ? kTextSecondary : textColor.withOpacity(0.5),
                    size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text("CastNow P2P Engine v2.5",
            style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink("TERMS", () => _showInfoDialog(context, "Terms of Use", "Free for personal use. CastNow Pro license required for commercial redistribution.")),
            _buildFooterSeparator(),
            _buildFooterLink("PRIVACY", () => _showInfoDialog(context, "Privacy Policy", "P2P connection is direct. No media data is stored on our servers.")),
            _buildFooterSeparator(),
            _buildFooterLink("HELP", () => _launchURL("mailto:minghua.liu@eastlakestudio.com")),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: const TextStyle(
              color: kTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
    );
  }

  Widget _buildFooterSeparator() {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration:
          const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
    );
  }
}
