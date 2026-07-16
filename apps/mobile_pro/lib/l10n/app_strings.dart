/// English-only string constants for CastNow.
/// Replaces the bilingual AppLocalizations class.
class AppStrings {
  const AppStrings._();

  // ─── Common ───────────────────────────────────────────────────────────────
  static const String appTitle = 'CastNow - Screen Cast';
  static const String close = 'CLOSE';
  static const String open = 'OPEN';

  // ─── Home ─────────────────────────────────────────────────────────────────
  static const String p2pSecure = 'P2P SECURE';
  static const String receiveOn = 'Receive on: ';
  static const String broadcast = 'Broadcast';
  static const String broadcastSubtitle = 'Share camera or screen';
  static const String receive = 'Receive';
  static const String receiveSubtitle = 'Watch a stream';
  static const String getPro = 'GET PRO';
  static const String pro = 'PRO';
  static const String footerEngine = 'CastNow P2P Engine v2.5';
  static const String footerManage = 'MANAGE';
  static const String footerTerms = 'TERMS';
  static const String footerPrivacy = 'PRIVACY';
  static const String footerHelp = 'HELP';

  // ─── Broadcast ────────────────────────────────────────────────────────────
  static const String broadcastSelectSource =
      'Please select at least one video (Screen or Camera).';
  static const String freeVersionLimit =
      'Free Version: Streaming is limited to 2 minutes.';
  static const String rtmpUrlRequired = 'Please enter RTMP URL.';
  static String criticalError(String error) => 'Critical Error: $error';
  static const String signalServerUnavailable =
      'Signal Server Unavailable. Please check your internet connection.';
  static const String broadcastScreen = 'Screen';
  static const String broadcastCamera = 'Camera';
  static const String broadcastMic = 'Mic';
  static const String broadcastStart = 'Start Broadcast';
  static const String broadcastStop = 'Stop Broadcast';
  static const String broadcastConnecting = 'Connecting...';
  static const String broadcastConnected = 'Connected';
  static const String pairCode = 'Pair Code';

  // ─── Receive ──────────────────────────────────────────────────────────────
  static const String receiveEnterCode = 'Enter 6-digit code';
  static const String receiveJoin = 'Join Stream';
  static const String receiveLeave = 'Leave';

  // ─── Paywall ──────────────────────────────────────────────────────────────
  static const String paywallTitle = 'Upgrade to Pro';
  static const String paywallUnlimitedTime = 'Unlimited Time';
  static const String paywallRtmp = 'RTMP Streaming';
  static const String paywallAllDevices = 'All Devices';
  static const String paywallRestore = 'Restore Purchase';
}
