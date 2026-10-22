import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/finance_profile_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/colors.dart';
import '../widgets/edit_transaction_sheet.dart';
import '../widgets/transaction_item.dart';
import 'history_screen.dart';

class TodayExpensesScreen extends StatefulWidget {
  const TodayExpensesScreen({super.key});

  @override
  State<TodayExpensesScreen> createState() => _TodayExpensesScreenState();
}

class _TodayExpensesScreenState extends State<TodayExpensesScreen> {
  static const _previewLimit = 8;

  bool _selecting = false;
  final Set<String> _selectedIds = {};

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _startSelection(String localId) {
    setState(() {
      _selecting = true;
      _selectedIds
        ..clear()
        ..add(localId);
    });
  }

  void _toggleSelection(String localId) {
    setState(() {
      if (_selectedIds.contains(localId)) {
        _selectedIds.remove(localId);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        _selectedIds.add(localId);
      }
    });
  }

  void _selectAll(List<Transaction> txs) {
    setState(() {
      _selecting = true;
      _selectedIds
        ..clear()
        ..addAll(txs.map((t) => t.localId));
    });
  }

  Future<void> _confirmDelete(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RastroColors.surface,
        title: Text(
          count == 1 ? 'Apagar gasto?' : 'Apagar $count gastos?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: RastroColors.text,
          ),
        ),
        content: Text(
          'Esta ação remove os gastos do aparelho. Não dá para desfazer.',
          style: GoogleFonts.outfit(fontSize: 13, color: RastroColors.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: RastroColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Apagar',
              style: GoogleFonts.outfit(
                color: RastroColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<TransactionProvider>().removeMany(_selectedIds);
    if (!mounted) return;
    _exitSelection();
    await context.read<FinanceProfileProvider>().refreshSpending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1 ? 'Gasto apagado' : '$count gastos apagados',
        ),
      ),
    );
  }

  Future<void> _applyEssentialBulk(bool essential) async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;

    await context
        .read<TransactionProvider>()
        .setEssentialMany(_selectedIds, essential);
    if (!mounted) return;
    _exitSelection();
    await context.read<FinanceProfileProvider>().refreshSpending();
    if (!mounted) return;

    final label = essential ? 'essenciais' : 'não-essenciais';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Gasto marcado como ${essential ? 'essencial' : 'não-essencial'}'
              : '$count gastos marcados como $label',
        ),
      ),
    );
  }

  void _openHistory({bool todayOnly = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(todayOnly: todayOnly),
      ),
    );
  }

  Widget _selectionToolbar(List<Transaction> txs) {
    final count = _selectedIds.length;
    final hasSelection = count > 0;
    final countLabel = count == 0
        ? 'Nenhum selecionado'
        : count == 1
            ? '1 selecionado'
            : '$count selecionados';

    Color actionColor(Color enabled) =>
        hasSelection ? enabled : RastroColors.muted.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: _exitSelection,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancelar',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RastroColors.muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                countLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RastroColors.sub,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _selectAll(txs),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Todos do dia',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RastroColors.accent,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed:
                  hasSelection ? () => _applyEssentialBulk(true) : null,
              icon: Icon(
                Icons.star_rounded,
                size: 22,
                color: actionColor(RastroColors.accent),
              ),
              tooltip: 'Marcar como essencial',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed:
                  hasSelection ? () => _applyEssentialBulk(false) : null,
              icon: Icon(
                Icons.block_rounded,
                size: 22,
                color: actionColor(RastroColors.danger),
              ),
              tooltip: 'Marcar como não-essencial',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: hasSelection ? () => _confirmDelete(count) : null,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: actionColor(RastroColors.danger),
              ),
              tooltip: 'Apagar selecionados',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TransactionProvider>();
    final txs = prov.todayList;
    final preview = txs.take(_previewLimit).toList();
    final hasMoreToday = txs.length > _previewLimit;
    final sectionHint = _selecting
        ? 'Toque para marcar ou desmarcar'
        : hasMoreToday
            ? 'Últimos $_previewLimit de ${txs.length}'
            : 'Toque para editar · segure para selecionar';

    return Scaffold(
      backgroundColor: RastroColors.base,
      appBar: AppBar(
        backgroundColor: RastroColors.base,
        elevation: 0,
        title: Text(
          'Gastos de hoje',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: RastroColors.text,
          ),
        ),
        iconTheme: const IconThemeData(color: RastroColors.sub),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              sectionHint,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(fontSize: 11, color: RastroColors.muted),
            ),
          ),
          if (txs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _selecting
                  ? _selectionToolbar(txs)
                  : Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _selecting = true),
                          child: Text(
                            'Selecionar',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: RastroColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          if (txs.isEmpty)
            _EmptyToday()
          else
            ...preview.map(
              (tx) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TransactionItem(
                  tx: tx,
                  selecting: _selecting,
                  selected: _selectedIds.contains(tx.localId),
                  onTap: () {
                    if (_selecting) {
                      _toggleSelection(tx.localId);
                      return;
                    }
                    showEditTransactionSheet(context, tx);
                  },
                  onLongPress: () => _startSelection(tx.localId),
                ),
              ),
            ),
          if (hasMoreToday) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _openHistory(todayOnly: true),
              child: Text('Ver todos os ${txs.length} gastos de hoje'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _openHistory(),
            child: const Text('Ver histórico completo'),
          ),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('💳', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Nenhum gasto registrado ainda hoje',
            style: GoogleFonts.outfit(fontSize: 14, color: RastroColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            'Use o botão Gasto ou aguarde notificações do banco',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: RastroColors.muted),
          ),
        ],
      ),
    );
  }
}
