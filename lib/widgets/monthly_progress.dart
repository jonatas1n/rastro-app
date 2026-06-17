import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import 'shared.dart';

Color _catColor(TransactionCategory cat) => switch (cat) {
  TransactionCategory.alimentacao => RastroColors.catAlimentacao,
  TransactionCategory.transporte  => RastroColors.catTransporte,
  TransactionCategory.saude       => RastroColors.catSaude,
  TransactionCategory.compras     => RastroColors.catCompras,
  TransactionCategory.lazer       => RastroColors.catLazer,
  TransactionCategory.mercado     => RastroColors.catMercado,
  TransactionCategory.outros      => RastroColors.sub,
};

class MonthlyProgressCard extends StatelessWidget {
  /// Map de categoria → valor gasto este mês
  final Map<TransactionCategory, double> currentMonth;

  /// Map de categoria → valor gasto mês anterior (referência)
  final Map<TransactionCategory, double> prevMonth;

  const MonthlyProgressCard({
    super.key,
    required this.currentMonth,
    required this.prevMonth,
  });

  @override
  Widget build(BuildContext context) {
    final cats = TransactionCategory.values
        .where((c) => c != TransactionCategory.outros)
        .toList();

    // Valor máximo entre todos para normalizar as barras
    double maxVal = 1;
    for (final c in cats) {
      final curr = currentMonth[c] ?? 0;
      final prev = prevMonth[c]    ?? 0;
      if (curr > maxVal) maxVal = curr;
      if (prev > maxVal) maxVal = prev;
    }

    return RastroCard(
      child: Column(
        children: [
          ...cats.map((cat) {
            final curr    = currentMonth[cat] ?? 0;
            final prev    = prevMonth[cat]    ?? 0;
            if (curr == 0 && prev == 0) return const SizedBox.shrink();

            final isOver    = curr > prev;
            final barColor  = isOver ? RastroColors.danger : RastroColors.safe;
            final currFrac  = curr / maxVal;
            final prevFrac  = prev / maxVal;

            return Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(cat.label,
                            style: GoogleFonts.dmSans(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: RastroColors.sub)),
                      ),
                      Text('ant. ${prev.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
                      const SizedBox(width: 10),
                      Text(curr.toStringAsFixed(0),
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: barColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 7,
                    child: Stack(children: [
                      // Track
                      Container(
                        decoration: BoxDecoration(
                          color: RastroColors.lift,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      // Mês anterior (referência, atrás)
                      FractionallySizedBox(
                        widthFactor: prevFrac.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: RastroColors.muted.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      // Este mês
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        widthFactor: currFrac.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            );
          }),

          // Legenda
          Row(
            children: [
              _LegendDot(color: RastroColors.muted, opacity: 0.25, label: 'Mês anterior'),
              const SizedBox(width: 18),
              _LegendDot(color: RastroColors.danger, label: 'Acima'),
              const SizedBox(width: 18),
              _LegendDot(color: RastroColors.safe, label: 'Abaixo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final double opacity;
  final String label;
  const _LegendDot({required this.color, this.opacity = 1, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12, height: 4,
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
      ],
    );
  }
}
