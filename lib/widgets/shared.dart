import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../models/transaction.dart';

// ── Valor monetário com R$ menor ───────────────────────────────────────────

class FmtValue extends StatelessWidget {
  final double amount;
  final double size;
  final Color  color;
  final bool   strikethrough;

  const FmtValue({
    super.key,
    required this.amount,
    this.size         = 28,
    this.color        = RastroColors.text,
    this.strikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    final parts   = amount.toStringAsFixed(2).split('.');
    final intPart = _formatInt(parts[0]);
    final decPart = parts[1];

    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: 'R\$ ',
          style: GoogleFonts.dmSans(
            fontSize:   size * 0.36,
            fontWeight: FontWeight.w500,
            color:      color.withValues(alpha: 0.5),
            decoration: strikethrough ? TextDecoration.lineThrough : null,
            decorationColor: RastroColors.danger,
          ),
        ),
        TextSpan(
          text: intPart,
          style: GoogleFonts.dmSans(
            fontSize:      size,
            fontWeight:    FontWeight.w700,
            color:         color,
            letterSpacing: -0.5,
            decoration:    strikethrough ? TextDecoration.lineThrough : null,
            decorationColor: RastroColors.danger,
          ),
        ),
        TextSpan(
          text: ',$decPart',
          style: GoogleFonts.dmSans(
            fontSize:   size * 0.52,
            fontWeight: FontWeight.w500,
            color:      color.withValues(alpha: 0.6),
            decoration: strikethrough ? TextDecoration.lineThrough : null,
            decorationColor: RastroColors.danger,
          ),
        ),
      ]),
    );
  }

  String _formatInt(String s) {
    // "1234" → "1.234"
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Cabeçalho de seção ─────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String  title;
  final String? right;

  const SectionLabel({super.key, required this.title, this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700, color: RastroColors.text)),
          if (right != null)
            Text(right!,
                style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.muted)),
        ],
      ),
    );
  }
}

// ── Card base com borda ────────────────────────────────────────────────────

class RastroCard extends StatelessWidget {
  final Widget  child;
  final Color?  borderColor;
  final Color?  background;
  final EdgeInsetsGeometry? padding;
  final double  radius;

  const RastroCard({
    super.key,
    required this.child,
    this.borderColor,
    this.background,
    this.padding,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        background ?? RastroColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? RastroColors.borderMd,
          width: 1.5,
        ),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

// ── Chip de categoria ──────────────────────────────────────────────────────

class CategoryChip extends StatelessWidget {
  final TransactionCategory category;
  final Color catColor;

  const CategoryChip({super.key, required this.category, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color:        catColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: catColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Center(child: Text(category.emoji, style: const TextStyle(fontSize: 17))),
    );
  }
}
