// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(Locale(locale));

  @override
  String get appTitle => 'CastNow - Screen Cast';

  @override
  String get p2pSecure => 'P2P SECURE';

  @override
  String get receiveOn => 'Receive on: ';

  @override
  String get broadcast => 'Broadcast';

  @override
  String get broadcastSubtitle => 'Share camera or screen';

  @override
  String get receive => 'Receive';

  @override
  String get receiveSubtitle => 'Watch a stream';

  @override
  String get getPro => 'GET PRO';

  @override
  String get pro => 'PRO';

  @override
  String get footerEngine => 'CastNow P2P Engine v2.5';

  @override
  String get footerManage => 'MANAGE';

  @override
  String get footerTerms => 'TERMS';

  @override
  String get footerPrivacy => 'PRIVACY';

  @override
  String get footerHelp => 'HELP';

  @override
  String get close => 'CLOSE';

  @override
  String get open => 'OPEN';

  @override
  String get broadcastSelectSource =>
      'Please select at least one video (Screen or Camera).';

  @override
  String get freeVersionLimit =>
      'Free Version: Streaming is limited to 2 minutes.';

  @override
  String get rtmpUrlRequired => 'Please enter RTMP URL.';

  @override
  String criticalError(String error) {
    return 'Critical Error: $error';
  }

  @override
  String get signalServerUnavailable =>
      'Signal Server Unavailable. Please check your internet connection.';

  @override
  String get broadcastScreen => 'Screen';

  @override
  String get broadcastCamera => 'Camera';

  @override
  String get broadcastMic => 'Mic';

  @override
  String get broadcastStart => 'Start Broadcast';

  @override
  String get broadcastStop => 'Stop Broadcast';

  @override
  String get broadcastConnecting => 'Connecting...';

  @override
  String get broadcastConnected => 'Connected';

  @override
  String get pairCode => 'Pair Code';

  @override
  String get receiveEnterCode => 'Enter 6-digit code';

  @override
  String get receiveJoin => 'Join Stream';

  @override
  String get receiveLeave => 'Leave';

  @override
  String get paywallTitle => 'Upgrade to Pro';

  @override
  String get paywallUnlimitedTime => 'Unlimited Time';

  @override
  String get paywallRtmp => 'RTMP Streaming';

  @override
  String get paywallAllDevices => 'All Devices';

  @override
  String get paywallRestore => 'Restore Purchase';
}
