import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'broadcast_screen.dart';
import 'receive_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../core/subscription_service.dart';
import '../widgets/paywall_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _checkAndRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = prefs.getInt('broadcast_completion_count') ?? 0;
      count++;
      await prefs.setInt('broadcast_completion_count', count);

      debugPrint('Broadcast completion count: $count');

      // Request review at specific milestones
      if (count == 3 || count == 10 || count == 20) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          debugPrint('Requesting App Store Review...');
          await inAppReview.requestReview();
        }
      }
    } catch (e) {
      debugPrint('Error in review prompt logic: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<SubscriptionService>().isSubscribed;
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
              Text(AppStrings.p2pSecure,
                  style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (!isPro) {
              showDialog(
                  context: context, builder: (_) => const PaywallDialog());
            }
          },
          child: Container(
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
        ),
        SizedBox(height: isLandscape ? 8 : 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'cast', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'now', style: TextStyle(color: kPrimaryColor)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded,
                    color: kPrimaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  AppStrings.receiveOn,
                  style: const TextStyle(
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
                      color: kPrimaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
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
            title: AppStrings.broadcast,
            subtitle: AppStrings.broadcastSubtitle,
            icon: Icons.wifi_tethering,
            color: kPrimaryColor,
            textColor: Colors.black,
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BroadcastScreen()));
              _checkAndRequestReview();
            },
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            context,
            title: AppStrings.receive,
            subtitle: AppStrings.receiveSubtitle,
            icon: Icons.download_rounded,
            color: kSurfaceColor,
            textColor: kTextPrimary,
            isOutlined: true,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReceiveScreen())),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(child: brandSection),
                                      Container(
                                          width: 1,
                                          height: 180,
                                          color: Colors.white10,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 40)),
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
                            _buildFooter(isPro),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  if (!isPro) {
                    showDialog(
                        context: context,
                        builder: (_) => const PaywallDialog());
                  } else {
                    // macOS 不支持 presentCustomerCenter，改为打开 App Store 订阅管理
                    if (Platform.isIOS) {
                      try {
                        RevenueCatUI.presentCustomerCenter();
                      } catch (e) {
                        debugPrint("Failed to show customer center: $e");
                      }
                    } else {
                      _launchURL("https://apps.apple.com/account/subscriptions");
                    }
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isPro
                        ? const LinearGradient(
                            colors: [Colors.cyan, Colors.blueAccent],
                          )
                        : const LinearGradient(
                            colors: [Colors.orangeAccent, Colors.redAccent],
                          ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isPro ? Colors.cyan : Colors.orangeAccent)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPro
                            ? Icons.verified_user_rounded
                            : Icons.bolt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPro ? AppStrings.pro : AppStrings.getPro,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
                    color: isOutlined
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon,
                      color: isOutlined ? kPrimaryColor : Colors.black87,
                      size: 28),
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
                              color: isOutlined
                                  ? kTextSecondary
                                  : textColor.withOpacity(0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: isOutlined
                        ? kTextSecondary
                        : textColor.withOpacity(0.5),
                    size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isPro) {
    return Column(
      children: [
        Text(AppStrings.footerEngine,
            style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPro) ...[
              _buildFooterLink(AppStrings.footerManage, () async {
                // macOS 不支持 presentCustomerCenter，改为打开 App Store 订阅管理
                if (Platform.isIOS) {
                  try {
                    await RevenueCatUI.presentCustomerCenter();
                  } catch (e) {
                    debugPrint("Failed to show customer center: $e");
                  }
                } else {
                  _launchURL("https://apps.apple.com/account/subscriptions");
                }
              }),
              _buildFooterSeparator(),
            ],
            _buildFooterLink(AppStrings.footerTerms,
                () => _launchURL("https://castnow.vercel.app/terms.html")),
            _buildFooterSeparator(),
            _buildFooterLink(AppStrings.footerPrivacy,
                () => _launchURL("https://castnow.vercel.app/privacy.html")),
            _buildFooterSeparator(),
            _buildFooterLink(
                AppStrings.footerHelp, () => _launchURL("mailto:mingh.liu@gmail.com")),
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
