import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/messages_provider.dart';
import '../theme/colors.dart';
import '../models/transaction.dart';
import '../widgets/shared.dart';
import '../widgets/savings_card.dart';
import '../widgets/transaction_item.dart';
import "../widgets/monthly_progress.dart";
import "../widgets/messages_sheet.dart";
import 'history_screen.dart';

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
      context.read<MessagesProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: RastroColors.base,
      body: SafeArea(
        child: prov.loading
            ? const Center(child: CircularProgressIndicator(color: RastroColors.accent))
            : RefreshIndicator(
                color: RastroColors.accent,
                backgroundColor: RastroColors.surface,
                onRefresh: () => context.read<TransactionProvider>().load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 40),
                  children: [
                    _Header(prov: prov),
                    const SizedBox(height: 12),
                    _TotalCard(prov: prov),
                    const SizedBox(height: 10),
                    SavingsCard(
                      nonEssentialToday: prov.nonEssentialToday,
                      totalToday:        prov.totalToday,
                      savingsWeek:       prov.savingsProjectionWeek,
                      savingsMonth:      prov.savingsProjectionMonth,
                    ),
                    const SizedBox(height: 10),
                    _SummaryCards(prov: prov),
                    const SizedBox(height: 16),
                    SectionLabel(title: 'Gastos de hoje', right: 'Toque para marcar'),
                    if (prov.todayList.isEmpty)
                      _EmptyToday()
                    else
                      ...prov.todayList.map((tx) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TransactionItem(
                              tx:       tx,
                              onToggle: () =>
                                  context.read<TransactionProvider>().toggleEssential(tx),
                            ),
                          )),
                    const SizedBox(height: 16),
                    SectionLabel(
                      title: 'Progressão do mês',
                      right: DateFormat('MMMM', 'pt_BR').format(DateTime.now()),
                    ),
                    _MonthlySection(prov: prov),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final TransactionProvider prov;
  const _Header({required this.prov});

  @override
  Widget build(BuildContext context) {
    final avgWeek  = prov.weekAvg;
    final total    = prov.totalToday;
    final diffPct  = avgWeek > 0 ? ((total - avgWeek) / avgWeek * 100).round() : 0;
    final isUp     = diffPct > 0;
    final diffColor = isUp ? RastroColors.danger : RastroColors.safe;
    final weekday  = DateFormat('EEEE · d MMM', 'pt_BR').format(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(weekday,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500,
                  color: RastroColors.muted)),
          const SizedBox(height: 3),
          Text('Rastro',
              style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800,
                  color: RastroColors.text, letterSpacing: -0.5)),
        ]),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        RastroColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: RastroColors.border),
                ),
                child: const Icon(Icons.history_rounded, color: RastroColors.sub, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            const MessagesBadge(),
            if (avgWeek > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color:        diffColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: diffColor.withOpacity(0.28)),
                ),
                child: Text(
                  '${isUp ? '↑' : '↓'} ${diffPct.abs()}% vs semana',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w600, color: diffColor),
                ),
              ),
            ],
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

    return RastroCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL HOJE',
              style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w600, color: RastroColors.muted,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          FmtValue(amount: total, size: 48),
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
                Text('Cortável R\$ ${nonEss.toStringAsFixed(0)}',
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
        ],
      ),
    );
  }
}

// ── 3 Summary Cards ──────────────────────────────────────────────────────────

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
      const SizedBox(width: 8),
      Expanded(child: _CountCard(
        label: 'Transações',
        count: prov.todayList.length,
        sub:   'hoje',
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

class _CountCard extends StatelessWidget {
  final String label, sub;
  final int    count;
  const _CountCard({required this.label, required this.count, required this.sub});

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
        Text('$count',
            style: GoogleFonts.dmSans(
                fontSize: 32, fontWeight: FontWeight.w800, color: RastroColors.accent, height: 1)),
        const SizedBox(height: 5),
        Text(sub, style: GoogleFonts.dmSans(fontSize: 10, color: RastroColors.muted)),
      ]),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(children: [
        const Text('💳', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 10),
        Text('Nenhum gasto registrado ainda hoje',
            style: GoogleFonts.dmSans(fontSize: 13, color: RastroColors.muted)),
        const SizedBox(height: 4),
        Text('As notificações serão capturadas automaticamente',
            style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.muted)),
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
