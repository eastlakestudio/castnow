// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CastNow - 屏幕投屏';

  @override
  String get p2pSecure => 'P2P 加密';

  @override
  String get receiveOn => '接收地址：';

  @override
  String get broadcast => '投屏';

  @override
  String get broadcastSubtitle => '共享摄像头或屏幕';

  @override
  String get receive => '接收';

  @override
  String get receiveSubtitle => '观看投屏画面';

  @override
  String get getPro => '升级 PRO';

  @override
  String get pro => 'PRO';

  @override
  String get footerEngine => 'CastNow P2P 引擎 v2.5';

  @override
  String get footerManage => '管理订阅';

  @override
  String get footerTerms => '使用条款';

  @override
  String get footerPrivacy => '隐私政策';

  @override
  String get footerHelp => '帮助';

  @override
  String get close => '关闭';

  @override
  String get open => '打开';

  @override
  String get broadcastSelectSource => '请至少选择一个视频来源（屏幕或摄像头）。';

  @override
  String get freeVersionLimit => '免费版：投屏时长限制为 2 分钟。';

  @override
  String get rtmpUrlRequired => '请输入 RTMP 推流地址。';

  @override
  String criticalError(String error) {
    return '严重错误：$error';
  }

  @override
  String get signalServerUnavailable => '信令服务器不可用，请检查网络连接。';

  @override
  String get broadcastScreen => '屏幕';

  @override
  String get broadcastCamera => '摄像头';

  @override
  String get broadcastMic => '麦克风';

  @override
  String get broadcastStart => '开始投屏';

  @override
  String get broadcastStop => '停止投屏';

  @override
  String get broadcastConnecting => '连接中…';

  @override
  String get broadcastConnected => '已连接';

  @override
  String get pairCode => '配对码';

  @override
  String get receiveEnterCode => '输入 6 位配对码';

  @override
  String get receiveJoin => '加入投屏';

  @override
  String get receiveLeave => '离开';

  @override
  String get paywallTitle => '升级到 Pro 版';

  @override
  String get paywallUnlimitedTime => '无限时长';

  @override
  String get paywallRtmp => 'RTMP 推流';

  @override
  String get paywallAllDevices => '支持所有设备';

  @override
  String get paywallRestore => '恢复购买';
}
