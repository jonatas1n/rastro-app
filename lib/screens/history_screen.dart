import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../providers/history_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/colors.dart';
import '../widgets/shared.dart';
import '../widgets/transaction_item.dart';
import '../widgets/edit_transaction_sheet.dart';

class HistoryScreen extends StatefulWidget {
  /// Abre já filtrado para o dia atual.
  final bool todayOnly;

  /// Segunda página do dashboard — sem [Scaffold] extra; [onBack] em vez de pop.
  final bool embedded;

  final VoidCallback? onBack;

  const HistoryScreen({
    super.key,
    this.todayOnly = false,
    this.embedded = false,
    this.onBack,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryProvider _prov;
  final _searchCtrl  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  bool _showFilters  = false;

  @override
  void initState() {
    super.initState();
    _prov = HistoryProvider();
    _scrollCtrl.addListener(_onScroll);
    if (widget.todayOnly) {
      final now = DateTime.now();
      _prov.setDateRange(
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    } else {
      // Lista padrão usa TransactionProvider (janelas de 7 dias).
    }
  }

  @override
  void dispose() {
    _prov.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_prov.filter.isEmpty) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _prov.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final column = Column(
      children: [
        _TopBar(
          searchCtrl: _searchCtrl,
          showFilters: _showFilters,
          onToggleFilters: () => setState(() => _showFilters = !_showFilters),
          onSearch: _prov.setQuery,
          onBack: widget.onBack,
        ),
        if (_showFilters) _FilterRow(prov: _prov),
        _SummaryStrip(),
        Expanded(child: _ResultsList(scrollCtrl: _scrollCtrl)),
      ],
    );

    return ChangeNotifierProvider.value(
      value: _prov,
      child: widget.embedded
          ? ColoredBox(color: RastroColors.base, child: column)
          : Scaffold(
              backgroundColor: RastroColors.base,
              body: SafeArea(child: column),
            ),
    );
  }
}

// ── Top bar: back + search + filter toggle ────────────────────────────────────

class _TopBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final bool showFilters;
  final VoidCallback onToggleFilters;
  final void Function(String) onSearch;
  final VoidCallback? onBack;

  const _TopBar({
    required this.searchCtrl,
    required this.showFilters,
    required this.onToggleFilters,
    required this.onSearch,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<HistoryProvider>();
    return Container(
      color: RastroColors.base,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RastroColors.sub, size: 18),
            onPressed: () {
              if (onBack != null) {
                onBack!();
                return;
              }
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        RastroColors.surface,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: RastroColors.border),
              ),
              child: TextField(
                controller:  searchCtrl,
                onChanged:   onSearch,
                textAlignVertical: TextAlignVertical.center,
                style: GoogleFonts.outfit(fontSize: 13, color: RastroColors.text, height: 1.2),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:       'Buscar estabelecimento...',
                  hintStyle:      GoogleFonts.outfit(fontSize: 13, color: RastroColors.muted, height: 1.2),
                  prefixIcon: const Icon(Icons.search_rounded, color: RastroColors.muted, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                          icon: const Icon(Icons.close_rounded, color: RastroColors.muted, size: 16),
                          onPressed: () {
                            searchCtrl.clear();
                            onSearch('');
                          },
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(right: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleFilters,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: showFilters
                    ? RastroColors.accent.withValues(alpha: 0.15)
                    : RastroColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: showFilters ? RastroColors.accent.withValues(alpha: 0.4) : RastroColors.border,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.filter_list_rounded,
                      color: showFilters ? RastroColors.accent : RastroColors.sub, size: 18),
                  if (!prov.filter.isEmpty)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          color: RastroColors.accent, shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final HistoryProvider prov;
  const _FilterRow({required this.prov});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<HistoryProvider>().filter;
    return Container(
      color: RastroColors.base,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        children: [
          // Categorias
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CatChip(label: 'Todas', selected: filter.category == null,
                    onTap: () => prov.setCategory(null)),
                ...TransactionCategory.values.map((c) => _CatChip(
                  label: '${c.emoji} ${c.label}',
                  selected: filter.category == c,
                  onTap: () => prov.setCategory(filter.category == c ? null : c),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Essencial toggle + date range
          Row(
            children: [
              _ToggleChip(
                label:    'Essencial',
                selected: filter.essentialOnly == true,
                onTap:    () => prov.setEssentialOnly(filter.essentialOnly == true ? null : true),
              ),
              const SizedBox(width: 6),
              _ToggleChip(
                label:    'Não-essencial',
                selected: filter.essentialOnly == false,
                onTap:    () => prov.setEssentialOnly(filter.essentialOnly == false ? null : false),
                color:    RastroColors.danger,
              ),
              const Spacer(),
              _DateRangeButton(prov: prov, filter: filter),
            ],
          ),
          // Limpar filtros
          if (!filter.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: prov.clearFilters,
                icon: const Icon(Icons.close_rounded, size: 14, color: RastroColors.muted),
                label: Text('Limpar filtros',
                    style: GoogleFonts.outfit(fontSize: 11, color: RastroColors.muted)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  const _CatChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? RastroColors.accent.withValues(alpha: 0.15) : RastroColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? RastroColors.accent.withValues(alpha: 0.5) : RastroColors.border,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? RastroColors.accent : RastroColors.sub,
            )),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String     label;
  final bool       selected;
  final VoidCallback onTap;
  final Color      color;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = RastroColors.safe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : RastroColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color.withValues(alpha: 0.4) : RastroColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? color : RastroColors.sub,
            )),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final HistoryProvider prov;
  final HistoryFilter   filter;

  const _DateRangeButton({required this.prov, required this.filter});

  @override
  Widget build(BuildContext context) {
    final hasRange = filter.from != null || filter.to != null;
    final label = hasRange
        ? '${_d(filter.from)} – ${_d(filter.to)}'
        : 'Período';

    return GestureDetector(
      onTap: () async {
        final range = await showDateRangePicker(
          context:          context,
          firstDate:        DateTime(2024),
          lastDate:         DateTime.now(),
          initialDateRange: filter.from != null && filter.to != null
              ? DateTimeRange(start: filter.from!, end: filter.to!)
              : null,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary:   RastroColors.accent,
                onPrimary: Colors.black,
                surface:   RastroColors.surface,
              ),
            ),
            child: child!,
          ),
        );
        if (range != null) prov.setDateRange(range.start, range.end);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasRange ? RastroColors.info.withValues(alpha: 0.12) : RastroColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hasRange ? RastroColors.info.withValues(alpha: 0.4) : RastroColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 12,
                color: hasRange ? RastroColors.info : RastroColors.muted),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: hasRange ? RastroColors.info : RastroColors.sub,
                )),
          ],
        ),
      ),
    );
  }

  String _d(DateTime? dt) => dt != null ? DateFormat('dd/MM').format(dt) : '?';
}

// ── Summary strip ─────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final histProv = context.watch<HistoryProvider>();
    final hasFilter = !histProv.filter.isEmpty;

    if (hasFilter) {
      if (histProv.results.isEmpty && !histProv.loading) {
        return const SizedBox.shrink();
      }
      return _SummaryContent(
        countLabel: '${histProv.total} gastos',
        total: histProv.filteredTotal,
        nonEssential: histProv.filteredNonEssential,
      );
    }

    final txProv = context.watch<TransactionProvider>();
    if (txProv.loading && txProv.historyWindowTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = txProv.historyWindowTransactions.length;
    return _SummaryContent(
      countLabel: count == 1 ? '1 gasto' : '$count gastos',
      total: txProv.historyWindowTotal,
      nonEssential: txProv.historyWindowNonEssential,
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final String countLabel;
  final double total;
  final double nonEssential;

  const _SummaryContent({
    required this.countLabel,
    required this.total,
    required this.nonEssential,
  });

  @override
  Widget build(BuildContext context) {
    final nonEssPct = total > 0 ? (nonEssential / total * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        RastroColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: RastroColors.borderMd),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCell(
            label: countLabel,
            value: total,
          )),
          _Divider(),
          Expanded(child: _StatCell(
            label: 'Não-essencial',
            value: nonEssential,
            color: nonEssential > 0 ? RastroColors.danger : RastroColors.muted,
            suffix: nonEssential > 0 ? ' ($nonEssPct%)' : '',
          )),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  final String suffix;

  const _StatCell({
    required this.label,
    required this.value,
    this.color  = RastroColors.text,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, color: RastroColors.muted)),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FmtValue(amount: value, size: 16, color: color),
            if (suffix.isNotEmpty)
              Text(suffix,
                  style: GoogleFonts.outfit(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: RastroColors.border, margin: const EdgeInsets.symmetric(horizontal: 12));
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _ResultsList({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final histProv = context.watch<HistoryProvider>();
    final hasFilter = !histProv.filter.isEmpty;

    if (hasFilter) {
      return _FilteredResultsList(scrollCtrl: scrollCtrl, prov: histProv);
    }

    return _WindowedResultsList(scrollCtrl: scrollCtrl);
  }
}

class _WindowedResultsList extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _WindowedResultsList({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final txProv = context.watch<TransactionProvider>();

    if (txProv.loading && txProv.historyWindowTransactions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: RastroColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    final days = txProv.historyVisibleDays;
    final byDay = txProv.historyByDay;
    final extra = txProv.hasMoreHistory ? 1 : 0;

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      itemCount: days.length + extra,
      itemBuilder: (ctx, i) {
        if (i == days.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(
                onPressed: () => txProv.loadMoreHistory(),
                child: Text(
                  'Carregar mais',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: RastroColors.accent,
                  ),
                ),
              ),
            ),
          );
        }

        return _DaySection(day: days[i], txs: byDay[days[i]] ?? const []);
      },
    );
  }
}

class _FilteredResultsList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final HistoryProvider prov;

  const _FilteredResultsList({
    required this.scrollCtrl,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    if (prov.loading && prov.results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: RastroColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (!prov.loading && prov.results.isEmpty) {
      return const _EmptyState(hasFilter: true);
    }

    final byDay = prov.byDay;
    final days = prov.sortedDays;

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      itemCount: days.length + (prov.hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == days.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: RastroColors.accent,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final day = days[i];
        return _DaySection(day: day, txs: byDay[day] ?? const []);
      },
    );
  }
}

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<Transaction> txs;

  const _DaySection({required this.day, required this.txs});

  @override
  Widget build(BuildContext context) {
    final dayTotal = txs.fold(0.0, (s, t) => s + t.amount);
    final isToday = _isSameCalendarDay(day, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dayLabel(day),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RastroColors.sub,
                ),
              ),
              FmtValue(
                amount: dayTotal,
                size: 12,
                color: RastroColors.muted,
              ),
            ],
          ),
        ),
        if (txs.isEmpty && isToday)
          const _EmptyDayNote()
        else
          ...txs.map(
            (tx) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TransactionItem(
                tx: tx,
                onTap: () => showEditTransactionSheet(context, tx),
              ),
            ),
          ),
      ],
    );
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
  }
}

class _EmptyDayNote extends StatelessWidget {
  const _EmptyDayNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: RastroColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RastroColors.border),
      ),
      child: Text(
        'Nenhum gasto hoje',
        style: GoogleFonts.outfit(fontSize: 13, color: RastroColors.muted),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(hasFilter ? '🔍' : '📭', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            hasFilter ? 'Nenhum resultado para esse filtro' : 'Nenhum gasto registrado ainda',
            style: GoogleFonts.outfit(fontSize: 14, color: RastroColors.muted),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<HistoryProvider>().clearFilters(),
              child: Text('Limpar filtros',
                  style: GoogleFonts.outfit(fontSize: 12, color: RastroColors.accent)),
            ),
          ],
        ],
      ),
    );
  }
}
