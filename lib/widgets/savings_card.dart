import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import 'shared.dart';

class SavingsCard extends StatelessWidget {
  final double nonEssentialToday;
  final double totalToday;
  final double savingsWeek;
  final double savingsMonth;

  const SavingsCard({
    super.key,
    required this.nonEssentialToday,
    required this.totalToday,
    required this.savingsWeek,
    required this.savingsMonth,
  });

  @override
  Widget build(BuildContext context) {
    if (nonEssentialToday == 0) return const SizedBox.shrink();

    final ratio = totalToday > 0 ? nonEssentialToday / totalToday : 0.0;
    final pct   = (ratio * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: RastroColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RastroColors.safe.withValues(alpha: 0.22), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            decoration: BoxDecoration(
              color: RastroColors.safe.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: RastroColors.safe.withValues(alpha: 0.15)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🌱 Potencial de economia',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w700, color: RastroColors.safe)),
                _PillBadge('$pct% não-essencial', color: RastroColors.safe),
              ],
            ),
          ),

          // Grid 2x2
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Linha 1
                Row(children: [
                  Expanded(child: _MiniCell(label: 'Hoje',   value: nonEssentialToday, sub: 'não-essencial')),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniCell(label: 'Semana', value: savingsWeek,        sub: 'projeção 7 dias')),
                ]),
                const SizedBox(height: 8),

                // Linha 2 — mês full width com gráfico
                Container(
                  decoration: BoxDecoration(
                    color: RastroColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RastroColors.safe.withValues(alpha: 0.18), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Mês',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: RastroColors.safe)),
                            const SizedBox(height: 6),
                            FmtValue(amount: savingsMonth, size: 28, color: RastroColors.safe),
                            const SizedBox(height: 4),
                            Text('projeção 30 dias',
                                style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('$pct%',
                                style: GoogleFonts.dmSans(
                                    fontSize: 32, fontWeight: FontWeight.w800, color: RastroColors.safe,
                                    height: 1)),
                            const SizedBox(height: 4),
                            Text('do total',
                                style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SavingsBarChart(
                        today: nonEssentialToday,
                        week:  savingsWeek,
                        month: savingsMonth,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCell extends StatelessWidget {
  final String label, sub;
  final double value;
  const _MiniCell({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RastroColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RastroColors.safe.withValues(alpha: 0.16), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: RastroColors.safe)),
          const SizedBox(height: 6),
          FmtValue(amount: value, size: 20, color: RastroColors.safe),
          const SizedBox(height: 4),
          Text(sub, style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String text;
  final Color  color;
  const _PillBadge(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SavingsBarChart extends StatelessWidget {
  final double today, week, month;
  const _SavingsBarChart({required this.today, required this.week, required this.month});

  @override
  Widget build(BuildContext context) {
    final bars = [
      _Bar('Hoje',   today),
      _Bar('Semana', week),
      _Bar('Mês',    month),
    ];
    final maxVal = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final frac   = maxVal > 0 ? b.value / maxVal : 0.0;
          final height = 4 + frac * 44;
          final opacity = 0.45 + i * 0.275;

          final label = b.value >= 1000
              ? '${(b.value / 1000).toStringAsFixed(1)}k'
              : b.value.round().toString();

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(label,
                    style: GoogleFonts.dmSans(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: RastroColors.safe.withValues(alpha: opacity + 0.2))),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  height: height,
                  decoration: BoxDecoration(
                    color: RastroColors.safe.withValues(alpha: opacity),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(b.label,
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w500,
                        color: RastroColors.muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Bar {
  final String label;
  final double value;
  const _Bar(this.label, this.value);
}
