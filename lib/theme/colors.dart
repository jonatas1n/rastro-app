import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RastroColors {
  // Fundos
  static const bg      = Color(0xFF0D0D0D);
  static const base    = Color(0xFF141414);
  static const surface = Color(0xFF1A1A1A);
  static const card    = Color(0xFF212121);
  static const lift    = Color(0xFF282828);

  // Bordas
  static const border   = Color(0xFF303030);
  static const borderMd = Color(0xFF3A3A3A);

  // Texto
  static const text  = Color(0xFFEFEFEF);
  static const sub   = Color(0xFFAAAAAA);
  static const muted = Color(0xFF666666);

  // Acentos
  static const accent = Color(0xFFA8FF3E); // verde lima
  static const danger = Color(0xFFFF5252); // vermelho
  static const safe   = Color(0xFF2ECC71); // verde seguro
  static const info   = Color(0xFF5B8DEF); // azul suave

  // Categorias
  static const catAlimentacao = Color(0xFFFF7043);
  static const catTransporte  = Color(0xFF5B8DEF);
  static const catSaude       = Color(0xFF2ECC71);
  static const catCompras     = Color(0xFFAB47BC);
  static const catLazer       = Color(0xFFEC407A);
  static const catMercado     = Color(0xFFFFA726);
}

class RastroTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: RastroColors.base,
      colorScheme: const ColorScheme.dark(
        primary:   RastroColors.accent,
        secondary: RastroColors.safe,
        surface:   RastroColors.surface,
        error:     RastroColors.danger,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor:    RastroColors.text,
        displayColor: RastroColors.text,
      ),
      cardColor: RastroColors.card,
      dividerColor: RastroColors.border,
    );
  }
}
