import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/finance_profile_provider.dart';
import '../theme/colors.dart';
import '../models/transaction.dart';
import '../widgets/shared.dart';
import '../widgets/savings_card.dart';
import "../widgets/monthly_progress.dart";
import '../widgets/budget_progress_card.dart';
import "../widgets/messages_sheet.dart";
import '../widgets/add_transaction_sheet.dart';
import 'finance_settings_screen.dart';
import 'notification_history_screen.dart';
import 'notification_debug_screen.dart';
import 'today_expenses_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().load();
      context.read<FinanceProfileProvider>().refreshSpending();
      context.read<MessagesProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: RastroColors.base,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTransactionSheet(context),
        backgroundColor: RastroColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Gasto',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: prov.loading
            ? const Center(child: CircularProgressIndicator(color: RastroColors.accent))
            : RefreshIndicator(
                color: RastroColors.accent,
                backgroundColor: RastroColors.surface,
                onRefresh: () async {
                  final txProv = context.read<TransactionProvider>();
                  final finProv = context.read<FinanceProfileProvider>();
                  await txProv.load();
                  await finProv.refreshSpending();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 88),
                  children: [
                    const _Header(),
                    const SizedBox(height: 12),
                    _TotalCard(prov: prov),
                    const SizedBox(height: 10),
                    const BudgetProgressCard(),
                    const SizedBox(height: 10),
                    SavingsCard(
                      nonEssentialToday: prov.nonEssentialToday,
                      totalToday:        prov.totalToday,
                      savingsWeek:       prov.savingsProjectionWeek,
                      savingsMonth:      prov.savingsProjectionMonth,
                    ),
                    const SizedBox(height: 10),
                    _SummaryCards(prov: prov),
                    if (_hasMonthlyProgress(prov)) ...[
                      const SizedBox(height: 16),
                      SectionLabel(
                        title: 'Progressão do mês',
                        right: DateFormat('MMMM', 'pt_BR')
                            .format(DateTime.now()),
                      ),
                      _MonthlySection(prov: prov),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

bool _hasMonthlyProgress(TransactionProvider prov) {
  for (final cat in TransactionCategory.values) {
    if (cat == TransactionCategory.outros) continue;
    if ((prov.monthByCategory[cat] ?? 0) > 0) return true;
  }
  return false;
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [RastroColors.safe, Colors.white],
            ).createShader(bounds),
            child: Text(
              'rastro',
              style: GoogleFonts.dmSans(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1,
              ),
            ),
          ),
        ]),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FinanceSettingsScreen())),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RastroColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RastroColors.border),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: RastroColors.sub, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationHistoryScreen(),
                ),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RastroColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RastroColors.border),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: RastroColors.sub, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationDebugScreen(),
                ),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RastroColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RastroColors.border),
                ),
                child: const Icon(Icons.bug_report_outlined,
                    color: RastroColors.sub, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            const MessagesBadge(),
          ],
        ),
      ],
    );
  }
}

// ── Total Hoje ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final TransactionProvider prov;
  const _TotalCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    final total       = prov.totalToday;
    final essential   = prov.essentialToday;
    final nonEss      = prov.nonEssentialToday;
    final nonEssPct   = total > 0 ? nonEss / total : 0.0;
    final avgWeek     = prov.weekAvg;
    final diffPct     = avgWeek > 0 ? ((total - avgWeek) / avgWeek * 100).round() : 0;
    final showDelta   = avgWeek > 0;

    return RastroCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL HOJE',
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: RastroColors.muted,
                      letterSpacing: 0.4)),
              const Spacer(),
              Text(
                _todayCountLabel(prov.todayList.length),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: RastroColors.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FmtValue(amount: total, size: 48),
              ),
              if (showDelta) _DailySpendDeltaBadge(diffPct: diffPct),
            ],
          ),
          if (nonEss > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(text: TextSpan(
                  style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.muted),
                  children: [
                    const TextSpan(text: 'Essencial '),
                    TextSpan(text: 'R\$ ${essential.toStringAsFixed(0)}',
                        style: const TextStyle(color: RastroColors.sub, fontWeight: FontWeight.w600)),
                  ],
                )),
                Text('Não-essencial R\$ ${nonEss.toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, fontWeight: FontWeight.w600, color: RastroColors.danger)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(children: [
                  Flexible(
                    flex: ((1 - nonEssPct) * 1000).round(),
                    child: Container(color: RastroColors.accent),
                  ),
                  Flexible(
                    flex: (nonEssPct * 1000).round(),
                    child: Container(color: RastroColors.danger),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TodayExpensesScreen(),
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ver gastos de hoje',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RastroColors.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: RastroColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _todayCountLabel(int count) {
    if (count == 0) return 'Nenhum gasto hoje';
    if (count == 1) return '1 gasto hoje';
    return '$count gastos hoje';
  }
}

class _DailySpendDeltaBadge extends StatelessWidget {
  final int diffPct;
  const _DailySpendDeltaBadge({required this.diffPct});

  @override
  Widget build(BuildContext context) {
    final isUp = diffPct > 0;
    final isDown = diffPct < 0;
    final color = isUp
        ? RastroColors.danger
        : isDown
            ? RastroColors.safe
            : RastroColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp
                ? Icons.arrow_upward_rounded
                : isDown
                    ? Icons.arrow_downward_rounded
                    : Icons.remove_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${diffPct.abs()}%',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Cards ────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final TransactionProvider prov;
  const _SummaryCards({required this.prov});

  @override
  Widget build(BuildContext context) {
    final biggest = prov.biggestToday;
    final topCat  = prov.topCategoryToday;

    return Row(children: [
      Expanded(child: _SmallCard(
        label: 'Maior gasto',
        value: biggest?.amount ?? 0,
        sub:   biggest?.place  ?? '—',
      )),
      const SizedBox(width: 8),
      Expanded(child: _SmallCard(
        label:   'Top categoria',
        value:   prov.monthByCategory[topCat] ?? 0,
        sub:     topCat != null ? '${topCat.emoji} ${topCat.label}' : '—',
      )),
    ]);
  }
}

class _SmallCard extends StatelessWidget {
  final String label, sub;
  final double value;
  const _SmallCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return RastroCard(
      radius: 10,
      padding: const EdgeInsets.fromLTRB(11, 13, 11, 11),
      background: RastroColors.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
                color: RastroColors.muted)),
        const SizedBox(height: 7),
        FmtValue(amount: value, size: 17),
        const SizedBox(height: 5),
        Text(sub,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
      ]),
    );
  }
}

// ── Monthly section ──────────────────────────────────────────────────────────

class _MonthlySection extends StatelessWidget {
  final TransactionProvider prov;
  const _MonthlySection({required this.prov});

  @override
  Widget build(BuildContext context) {
    // Mês anterior simulado como 90% dos valores atuais (placeholder até ter dados reais)
    final prevMonth = {
      for (final e in prov.monthByCategory.entries)
        e.key: e.value * 0.9,
    };

    return MonthlyProgressCard(
      currentMonth: prov.monthByCategory,
      prevMonth:    prevMonth,
    );
  }
}
