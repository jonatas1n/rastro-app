import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../widgets/history_swipe_hint.dart';
import '../services/app_preferences.dart';
import 'finance_settings_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _outerViewportFraction = 0.95;
  static const _idleHintDuration = Duration(seconds: 9);
  static const _historyOuterPage = 0;
  static const _dashboardOuterPage = 1;

  late final PageController _dayPageController;
  late final PageController _outerPageController;
  DateTime _selectedDay = TransactionProvider.calendarDay(DateTime.now());
  int _outerPageIndex = _dashboardOuterPage;
  bool _showSwipeHint = false;
  bool _hintMarkedSeenInPrefs = false;
  Timer? _idleHintTimer;

  @override
  void initState() {
    super.initState();
    _dayPageController = PageController(
      initialPage: TransactionProvider.carouselTodayPageIndex,
    );
    _outerPageController = PageController(
      initialPage: _dashboardOuterPage,
      viewportFraction: _outerViewportFraction,
    );
    _outerPageController.addListener(_onOuterPageActivity);
    _initSwipeHint();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final txProv = context.read<TransactionProvider>();
      await txProv.load();
      if (!mounted) return;
      final restoreErr = txProv.restoreError;
      if (restoreErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restoreErr),
            backgroundColor: RastroColors.danger,
          ),
        );
      }
      final finProv = context.read<FinanceProfileProvider>();
      final finRestoreErr = finProv.restoreError;
      if (finRestoreErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finRestoreErr),
            backgroundColor: RastroColors.danger,
          ),
        );
      }
      _resetDayCarouselToToday(txProv);
      await finProv.refreshSpending();
      if (!mounted) return;
      context.read<MessagesProvider>().fetch();
    });
  }

  @override
  void dispose() {
    _idleHintTimer?.cancel();
    _outerPageController.removeListener(_onOuterPageActivity);
    _outerPageController.dispose();
    _dayPageController.dispose();
    super.dispose();
  }

  Future<void> _initSwipeHint() async {
    final seen = await AppPreferences.historySwipeHintSeen;
    if (!mounted) return;
    setState(() {
      _hintMarkedSeenInPrefs = seen;
      if (!seen) _showSwipeHint = true;
    });
    _scheduleIdleHint();
  }

  void _onOuterPageActivity() {
    if (!_outerPageController.hasClients) return;
    final page = _outerPageController.page;
    if (page != null && page < _dashboardOuterPage - 0.02) {
      _hideSwipeHint(persistFirstTime: true);
    }
  }

  void _onOuterPageChanged(int index) {
    setState(() => _outerPageIndex = index);
    _hideSwipeHint(persistFirstTime: true);
    _scheduleIdleHint();
  }

  void _onDashboardInteraction() {
    _hideSwipeHint(persistFirstTime: true);
    _scheduleIdleHint();
  }

  void _hideSwipeHint({required bool persistFirstTime}) {
    if (!_showSwipeHint) return;
    setState(() => _showSwipeHint = false);
    if (persistFirstTime && !_hintMarkedSeenInPrefs) {
      _hintMarkedSeenInPrefs = true;
      unawaited(AppPreferences.setHistorySwipeHintSeen(true));
    }
  }

  void _scheduleIdleHint() {
    _idleHintTimer?.cancel();
    if (_outerPageIndex != _dashboardOuterPage) return;
    _idleHintTimer = Timer(_idleHintDuration, () {
      if (!mounted || _outerPageIndex != _dashboardOuterPage) return;
      setState(() => _showSwipeHint = true);
    });
  }

  void _goToDashboardPage() {
    _outerPageController.animateToPage(
      _dashboardOuterPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToHistoryPage() {
    _outerPageController.animateToPage(
      _historyOuterPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetDayCarouselToToday(TransactionProvider prov) {
    final today = TransactionProvider.calendarDay(DateTime.now());
    setState(() => _selectedDay = today);
    final lastIndex = TransactionProvider.carouselTodayPageIndex;
    if (_dayPageController.hasClients) {
      _dayPageController.jumpToPage(lastIndex);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_dayPageController.hasClients) return;
        _dayPageController.jumpToPage(lastIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: RastroColors.base,
      floatingActionButton: _outerPageIndex == _dashboardOuterPage
          ? FloatingActionButton.extended(
              onPressed: () => showAddTransactionSheet(context),
              backgroundColor: RastroColors.accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Gasto',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _outerPageController,
              onPageChanged: _onOuterPageChanged,
              children: [
                HistoryScreen(
                  embedded: true,
                  onBack: _goToDashboardPage,
                ),
                _DashboardPage(
                  prov: prov,
                  dayPageController: _dayPageController,
                  selectedDay: _selectedDay,
                  onDayChanged: (day) {
                    if (_selectedDay == day) return;
                    setState(() => _selectedDay = day);
                  },
                  onInteraction: _onDashboardInteraction,
                  onOpenHistory: _goToHistoryPage,
                  onRefresh: () async {
                    final txProv = context.read<TransactionProvider>();
                    final finProv = context.read<FinanceProfileProvider>();
                    await txProv.load();
                    await finProv.refreshSpending();
                    if (!mounted) return;
                    _resetDayCarouselToToday(txProv);
                  },
                ),
              ],
            ),
            if (_showSwipeHint && _outerPageIndex == _dashboardOuterPage)
              const Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                left: 0,
                child: HistorySwipeHint(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  final TransactionProvider prov;
  final PageController dayPageController;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;
  final VoidCallback onInteraction;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onRefresh;

  const _DashboardPage({
    required this.prov,
    required this.dayPageController,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onInteraction,
    required this.onOpenHistory,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (prov.loading) {
      return const Center(
        child: CircularProgressIndicator(color: RastroColors.accent),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onInteraction(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification ||
              n is UserScrollNotification) {
            onInteraction();
          }
          return false;
        },
        child: RefreshIndicator(
          color: RastroColors.accent,
          backgroundColor: RastroColors.surface,
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 88),
            children: [
              const _Header(),
              const SizedBox(height: 12),
              _DaySpendCarousel(
                prov: prov,
                pageController: dayPageController,
                selectedDay: selectedDay,
                onDayChanged: onDayChanged,
                onOpenHistory: onOpenHistory,
              ),
              const SizedBox(height: 10),
              const BudgetProgressCard(),
              const SizedBox(height: 10),
              SavingsCard(
                nonEssentialToday: prov.nonEssentialForDay(selectedDay),
                totalToday: prov.totalForDay(selectedDay),
                savingsWeek:
                    prov.savingsProjectionWeekForDay(selectedDay),
                savingsMonth:
                    prov.savingsProjectionMonthForDay(selectedDay),
              ),
              const SizedBox(height: 10),
              _SummaryCards(prov: prov, day: selectedDay),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showMenu(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/logo.svg',
                width: 32,
                height: 32,
              ),
              const SizedBox(width: 10),
              Text(
                'rastro',
                style: GoogleFonts.outfit(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const MessagesBadge(),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => _RastroMenuDialog(),
    );
  }
}

class _RastroMenuDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RastroColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: RastroColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RastroMenuItem(
              icon: Icons.tune_rounded,
              label: 'Configurações',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FinanceSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RastroMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RastroMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: RastroColors.sub, size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day spend carousel ───────────────────────────────────────────────────────

class _DaySpendCarousel extends StatefulWidget {
  final TransactionProvider prov;
  final PageController pageController;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;
  final VoidCallback onOpenHistory;

  const _DaySpendCarousel({
    required this.prov,
    required this.pageController,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onOpenHistory,
  });

  static const _carouselHeight = 188.0;

  @override
  State<_DaySpendCarousel> createState() => _DaySpendCarouselState();
}

class _DaySpendCarouselState extends State<_DaySpendCarousel> {
  bool _historyEdgeTriggered = false;

  bool _notification(ScrollNotification n) {
    if (!widget.pageController.hasClients) return false;
    final page = widget.pageController.page ?? 0;
    if (page > 0.01) return false;

    if (n is ScrollStartNotification) {
      _historyEdgeTriggered = false;
      return false;
    }
    if (_historyEdgeTriggered) return false;

    if (n is OverscrollNotification && n.overscroll < 0) {
      _historyEdgeTriggered = true;
      widget.onOpenHistory();
      return false;
    }
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        n.metrics.pixels <= n.metrics.minScrollExtent + 0.5 &&
        (n.dragDetails!.primaryDelta ?? 0) > 0) {
      _historyEdgeTriggered = true;
      widget.onOpenHistory();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.prov.carouselDays;
    final selectedDay = widget.selectedDay;
    final pageController = widget.pageController;

    final currentIndex = days.indexWhere(
      (d) => d == TransactionProvider.calendarDay(selectedDay),
    );
    final activeIndex =
        currentIndex >= 0 ? currentIndex : days.length - 1;

    return Column(
      children: [
        SizedBox(
          height: _DaySpendCarousel._carouselHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: _notification,
            child: PageView.builder(
              controller: pageController,
              itemCount: days.length,
              onPageChanged: (i) => widget.onDayChanged(days[i]),
              itemBuilder: (context, i) => _TotalCard(
                prov: widget.prov,
                day: days[i],
              ),
            ),
          ),
        ),
        if (days.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chevron_left_rounded,
                  size: 16,
                  color: activeIndex > 0
                      ? RastroColors.sub
                      : RastroColors.border),
              const SizedBox(width: 6),
              ...List.generate(days.length, (i) {
                final selected = i == activeIndex;
                return Container(
                  width: selected ? 6 : 5,
                  height: selected ? 6 : 5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? RastroColors.accent
                        : RastroColors.border,
                  ),
                );
              }),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: activeIndex < days.length - 1
                      ? RastroColors.sub
                      : RastroColors.border),
            ],
          ),
        ],
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final TransactionProvider prov;
  final DateTime day;
  const _TotalCard({required this.prov, required this.day});

  bool get _isToday =>
      TransactionProvider.calendarDay(day) ==
      TransactionProvider.calendarDay(DateTime.now());

  bool get _isYesterday =>
      TransactionProvider.calendarDay(day) ==
      TransactionProvider.calendarDay(
        DateTime.now().subtract(const Duration(days: 1)),
      );

  String _headerLabel() {
    if (_isToday) return 'HOJE';
    if (_isYesterday) return 'Ontem';
    final raw = DateFormat('EEE, d \'de\' MMM', 'pt_BR').format(day);
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final total = prov.totalForDay(day);
    final essential = prov.essentialForDay(day);
    final nonEss = prov.nonEssentialForDay(day);
    final nonEssPct = total > 0 ? nonEss / total : 0.0;
    final avgWeek = prov.weekAvg;
    final diffPct =
        avgWeek > 0 ? ((total - avgWeek) / avgWeek * 100).round() : 0;
    final showDelta = _isToday && avgWeek > 0;
    final count = prov.transactionsForDay(day).length;

    return RastroCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(_headerLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: RastroColors.muted,
                        letterSpacing: 0.4)),
              ),
              const SizedBox(width: 8),
              Text(
                _countLabel(count),
                textAlign: TextAlign.right,
                style: GoogleFonts.outfit(
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
                RichText(
                    text: TextSpan(
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: RastroColors.muted),
                  children: [
                    const TextSpan(text: 'Essencial '),
                    TextSpan(
                        text: 'R\$ ${essential.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: RastroColors.sub,
                            fontWeight: FontWeight.w600)),
                  ],
                )),
                Text('Não-essencial R\$ ${nonEss.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: RastroColors.danger)),
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

  String _countLabel(int count) {
    if (_isToday) return _todayCountLabel(count);
    if (count == 0) return 'Nenhum gasto';
    if (count == 1) return '1 gasto';
    return '$count gastos';
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
            style: GoogleFonts.outfit(
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
  final DateTime day;
  const _SummaryCards({required this.prov, required this.day});

  @override
  Widget build(BuildContext context) {
    final biggest = prov.biggestForDay(day);
    final topCat = prov.topCategoryForDay(day);
    final catTotals = prov.categoryTotalsForDay(day);

    return Row(children: [
      Expanded(
          child: _SmallCard(
        label: 'Maior gasto',
        value: biggest?.amount ?? 0,
        sub: biggest?.place ?? '—',
      )),
      const SizedBox(width: 8),
      Expanded(
          child: _SmallCard(
        label: 'Top categoria',
        value: topCat != null ? (catTotals[topCat] ?? 0) : 0,
        sub: topCat != null ? '${topCat.emoji} ${topCat.label}' : '—',
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
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600,
                color: RastroColors.muted)),
        const SizedBox(height: 7),
        FmtValue(amount: value, size: 17),
        const SizedBox(height: 5),
        Text(sub,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 10, color: RastroColors.muted)),
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
