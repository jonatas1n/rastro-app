import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/finance_profile_provider.dart';
import '../screens/finance_settings_screen.dart';
import '../theme/colors.dart';
import 'shared.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceProfileProvider>();
    if (fin.loading) return const SizedBox.shrink();

    final p = fin.profile;
    if (!p.hasIncome && !p.hasAnyGoal) {
      if (fin.incomeSetupDismissed) return const SizedBox.shrink();
      return const _SetupPrompt();
    }

    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final period = fin.currentPeriod;
    final periodLabel =
        '${DateFormat('d/M').format(period.start)} – ${DateFormat('d/M').format(period.end)}';

    return RastroCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Suas metas',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, color: RastroColors.text)),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FinanceSettingsScreen()),
                ),
                child: Text('Editar',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: RastroColors.accent)),
              ),
            ],
          ),
          if (p.hasIncome) ...[
            const SizedBox(height: 8),
            Text('Ciclo $periodLabel · Renda ${fmt.format(p.monthlyIncome)}',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: RastroColors.muted)),
          ],
          if (p.weeklyLimitEnabled && (p.weeklySpendingLimit ?? 0) > 0) ...[
            const SizedBox(height: 12),
            _Bar(
              label: 'Semana',
              spent: fin.weekSpend,
              limit: p.weeklySpendingLimit!,
            ),
          ],
          if (p.monthlyLimitEnabled && (p.monthlySpendingLimit ?? 0) > 0) ...[
            const SizedBox(height: 10),
            _Bar(
              label: 'Ciclo',
              spent: fin.periodSpend,
              limit: p.monthlySpendingLimit!,
            ),
          ],
          if (p.monthEndBalanceEnabled && p.monthEndTargetBalance != null) ...[
            const SizedBox(height: 10),
            _BalanceRow(
              projected: fin.projectedPeriodBalance,
              target: p.monthEndTargetBalance!,
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context) {
    return RastroCard(
      padding: const EdgeInsets.all(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configure sua renda e metas',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              color: RastroColors.text)),
                      const SizedBox(height: 4),
                      Text('Defina quanto ganha e limites de gasto.',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: RastroColors.muted)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FinanceSettingsScreen()),
                  ),
                  child: const Text('Configurar'),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Fechar',
              onPressed: () => context
                  .read<FinanceProfileProvider>()
                  .dismissIncomeSetupPrompt(),
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: RastroColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double spent;
  final double limit;

  const _Bar({required this.label, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.2) : 0.0;
    final over = spent > limit;
    final color = over ? RastroColors.danger : RastroColors.accent;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${fmt.format(spent)} / ${fmt.format(limit)}',
                style: GoogleFonts.outfit(fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio > 1 ? 1 : ratio,
            minHeight: 6,
            backgroundColor: RastroColors.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final double? projected;
  final double target;

  const _BalanceRow({required this.projected, required this.target});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    if (projected == null) {
      return Text('Informe sua renda para projetar o saldo.',
          style: GoogleFonts.outfit(fontSize: 11, color: RastroColors.muted));
    }
    final ok = projected! >= target;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Saldo projetado no fim do ciclo',
            style: GoogleFonts.outfit(fontSize: 12, color: RastroColors.sub)),
        Text(
          '${fmt.format(projected!)} (meta ${fmt.format(target)})',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ok ? RastroColors.safe : RastroColors.danger,
          ),
        ),
      ],
    );
  }
}
