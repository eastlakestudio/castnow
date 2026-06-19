import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/subscription_service.dart';
import 'screens/home_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final subscriptionService = SubscriptionService();
  
  // 初始化服务，但不阻塞 runApp
  subscriptionService.init();

  runApp(
    ChangeNotifierProvider.value(
      value: subscriptionService,
      child: const CastNowApp(),
    ),
  );
}

class CastNowApp extends StatelessWidget {
  const CastNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'CastNow - Screen Cast',
      debugShowCheckedModeBanner: false,

      // 国际化配置
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackgroundColor,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          surface: kSurfaceColor,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

