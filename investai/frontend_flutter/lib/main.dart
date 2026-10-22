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

  runApp(
    DevicePreview(
      // Moldura de celular sempre em desenvolvimento e, na versão
      // compilada, só em tela de computador: no projetor o app aparece
      // num celular desenhado, e no celular de verdade fica sem moldura.
      enabled: kDebugMode || _telaDeComputador(),
      builder: (context) => const InvestAIApp(),
    ),
  );
}

/// Se a janela tem tamanho de computador. A altura mínima deixa de fora o
/// celular deitado, que é largo mas baixo.
bool _telaDeComputador() {
  final telas = WidgetsBinding.instance.platformDispatcher.views;
  if (telas.isEmpty) return false;
  final tela = telas.first;
  final tamanho = tela.physicalSize / tela.devicePixelRatio;
  return tamanho.width >= 700 && tamanho.height >= 500;
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
