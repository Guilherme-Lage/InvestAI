import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// Verifica junto ao backend se existe uma sessão (token JWT) válida.
/// Se sim → vai direto pra Home. Se não (ou expirada/revogada) → Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
    _checarSessao();
  }

  Future<void> _checarSessao() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    // Não basta existir algo salvo localmente: confirmamos com o backend
    // que o token ainda é válido (não expirou nem foi revogado por um
    // logout anterior) antes de considerar o usuário autenticado.
    final usuario = await ApiService.verificarSessao();

    Widget destino = usuario != null ? HomeScreen(usuario: usuario) : const LoginScreen();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destino,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InvestAITheme.fundo,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: InvestAITheme.verde,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: InvestAITheme.verdeEscuro,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'InvestAI',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: InvestAITheme.verde,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seu assistente financeiro',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: InvestAITheme.cinza,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
