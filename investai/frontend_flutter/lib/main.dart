import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';

/// Permite navegar (ex.: voltar para o login) a partir de fora da árvore
/// de widgets — usado pelo ApiService quando a sessão cai em qualquer tela.
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Device Preview ativo apenas em debug (desativa automaticamente em produção)
  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (context) => const InvestAIApp(),
    ),
  );
}

class InvestAIApp extends StatelessWidget {
  const InvestAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'InvestAI',
      debugShowCheckedModeBanner: false,
      theme: InvestAITheme.theme,
      // Necessário para o device_preview funcionar corretamente
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: const SplashScreen(),
    );
  }
}
