import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InvestAITheme {
  // Paleta fiel ao site de referência
  static const Color verde = Color(0xFF00C896);
  static const Color fundo = Color(0xFF0A1410);
  static const Color card = Color(0xFF12211B);
  static const Color borda = Color(0xFF1F3A2E);
  static const Color texto = Color(0xFFE8F5EF);
  static const Color cinza = Color(0xFF8AA79A);
  static const Color vermelho = Color(0xFFFF6B6B);
  static const Color verdeEscuro = Color(0xFF05231A);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fundo,
        colorScheme: const ColorScheme.dark(
          primary: verde,
          secondary: verde,
          surface: card,
          error: vermelho,
        ),
        textTheme: GoogleFonts.interTextTheme(
          const TextTheme(
            displayLarge: TextStyle(color: texto),
            bodyLarge: TextStyle(color: texto),
            bodyMedium: TextStyle(color: cinza),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          labelStyle: const TextStyle(color: cinza),
          hintStyle: TextStyle(color: cinza.withOpacity(0.6)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borda),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: verde, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: vermelho),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: vermelho, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: verde,
            foregroundColor: verdeEscuro,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: verde,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        useMaterial3: true,
      );
}
