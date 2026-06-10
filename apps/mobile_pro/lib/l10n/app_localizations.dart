import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 手写的国际化类，支持英文（en）和简体中文（zh）。
/// 不依赖 flutter gen-l10n 代码生成，直接可用。
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// 所有支持的国际化 delegate（传给 MaterialApp.localizationsDelegates）
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// App 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
  ];

  bool get _isZh => locale.languageCode == 'zh';

  // ─── 通用 ───────────────────────────────────────────────────────────────
  String get appTitle => _isZh ? 'CastNow - 屏幕投屏' : 'CastNow - Screen Cast';
  String get close => _isZh ? '关闭' : 'CLOSE';
  String get open => _isZh ? '打开' : 'OPEN';

  // ─── 首页 ────────────────────────────────────────────────────────────────
  String get p2pSecure => _isZh ? 'P2P 加密' : 'P2P SECURE';
  String get receiveOn => _isZh ? '接收地址：' : 'Receive on: ';
  String get broadcast => _isZh ? '投屏' : 'Broadcast';
  String get broadcastSubtitle => _isZh ? '共享摄像头或屏幕' : 'Share camera or screen';
  String get receive => _isZh ? '接收' : 'Receive';
  String get receiveSubtitle => _isZh ? '观看投屏画面' : 'Watch a stream';
  String get getPro => _isZh ? '升级 PRO' : 'GET PRO';
  String get pro => 'PRO';
  String get footerEngine =>
      _isZh ? 'CastNow P2P 引擎 v2.5' : 'CastNow P2P Engine v2.5';
  String get footerManage => _isZh ? '管理订阅' : 'MANAGE';
  String get footerTerms => _isZh ? '使用条款' : 'TERMS';
  String get footerPrivacy => _isZh ? '隐私政策' : 'PRIVACY';
  String get footerHelp => _isZh ? '帮助' : 'HELP';

  // ─── 投屏页 ──────────────────────────────────────────────────────────────
  String get broadcastSelectSource =>
      _isZh ? '请至少选择一个视频来源（屏幕或摄像头）。'
             : 'Please select at least one video (Screen or Camera).';
  String get freeVersionLimit =>
      _isZh ? '免费版：投屏时长限制为 2 分钟。'
             : 'Free Version: Streaming is limited to 2 minutes.';
  String get rtmpUrlRequired =>
      _isZh ? '请输入 RTMP 推流地址。' : 'Please enter RTMP URL.';
  String criticalError(String error) =>
      _isZh ? '严重错误：$error' : 'Critical Error: $error';
  String get signalServerUnavailable =>
      _isZh ? '信令服务器不可用，请检查网络连接。'
             : 'Signal Server Unavailable. Please check your internet connection.';
  String get broadcastScreen => _isZh ? '屏幕' : 'Screen';
  String get broadcastCamera => _isZh ? '摄像头' : 'Camera';
  String get broadcastMic => _isZh ? '麦克风' : 'Mic';
  String get broadcastStart => _isZh ? '开始投屏' : 'Start Broadcast';
  String get broadcastStop => _isZh ? '停止投屏' : 'Stop Broadcast';
  String get broadcastConnecting => _isZh ? '连接中…' : 'Connecting...';
  String get broadcastConnected => _isZh ? '已连接' : 'Connected';
  String get pairCode => _isZh ? '配对码' : 'Pair Code';

  // ─── 接收页 ──────────────────────────────────────────────────────────────
  String get receiveEnterCode => _isZh ? '输入 6 位配对码' : 'Enter 6-digit code';
  String get receiveJoin => _isZh ? '加入投屏' : 'Join Stream';
  String get receiveLeave => _isZh ? '离开' : 'Leave';

  // ─── 付费墙 ──────────────────────────────────────────────────────────────
  String get paywallTitle => _isZh ? '升级到 Pro 版' : 'Upgrade to Pro';
  String get paywallUnlimitedTime => _isZh ? '无限时长' : 'Unlimited Time';
  String get paywallRtmp => _isZh ? 'RTMP 推流' : 'RTMP Streaming';
  String get paywallAllDevices => _isZh ? '支持所有设备' : 'All Devices';
  String get paywallRestore => _isZh ? '恢复购买' : 'Restore Purchase';
}

// ─── Delegate ─────────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
