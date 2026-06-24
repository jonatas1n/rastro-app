import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/finance_profile_provider.dart';
import '../theme/colors.dart';
import '../utils/br_money_input.dart';

Future<void> showEditTransactionSheet(
  BuildContext context,
  Transaction tx,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RastroColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _EditTransactionSheet(tx: tx),
  );
}

class _EditTransactionSheet extends StatefulWidget {
  final Transaction tx;
  const _EditTransactionSheet({required this.tx});

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  late final TextEditingController _placeCtrl;
  late final TextEditingController _amountCtrl;
  late TransactionCategory _category;
  late bool _essential;
  late DateTime _when;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _placeCtrl = TextEditingController(text: widget.tx.place);
    _amountCtrl = TextEditingController(
      text: formatBrMoneyInput(widget.tx.amount),
    );
    _category = widget.tx.category;
    _essential = widget.tx.isEssential;
    _when = widget.tx.timestamp;
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseBrMoney(_amountCtrl.text);
    if (_placeCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe local e valor válidos')),
      );
      return;
    }
    setState(() => _saving = true);
    final txProv = context.read<TransactionProvider>();
    final finProv = context.read<FinanceProfileProvider>();
    await txProv.editTransaction(
      widget.tx,
      place: _placeCtrl.text.trim(),
      amount: amount,
      category: _category,
      isEssential: _essential,
      timestamp: _when,
    );
    await finProv.refreshSpending();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: RastroColors.surface,
        title: Text('Excluir gasto?',
            style: GoogleFonts.outfit(color: RastroColors.text)),
        content: Text('Esta ação remove o registro deste aparelho.',
            style: GoogleFonts.outfit(color: RastroColors.sub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Excluir',
                  style: TextStyle(color: RastroColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final txProv = context.read<TransactionProvider>();
    final finProv = context.read<FinanceProfileProvider>();
    await txProv.remove(widget.tx.localId);
    await finProv.refreshSpending();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editar gasto',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: RastroColors.text)),
          const SizedBox(height: 14),
          TextField(
            controller: _placeCtrl,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.outfit(color: RastroColors.text),
            decoration: const InputDecoration(labelText: 'Local / descrição'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [BrMoneyInputFormatter()],
            style: GoogleFonts.outfit(color: RastroColors.text),
            decoration: const InputDecoration(labelText: 'Valor (R\$)'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TransactionCategory>(
            value: _category,
            dropdownColor: RastroColors.card,
            style: GoogleFonts.outfit(color: RastroColors.text),
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: TransactionCategory.values
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.emoji} ${c.label}'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Essencial',
                style: GoogleFonts.outfit(color: RastroColors.text)),
            value: _essential,
            activeColor: RastroColors.accent,
            onChanged: (v) => setState(() => _essential = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Data e hora',
                style: GoogleFonts.outfit(color: RastroColors.text)),
            subtitle: Text(
              '${_when.day.toString().padLeft(2, '0')}/${_when.month.toString().padLeft(2, '0')} '
              '${_when.hour.toString().padLeft(2, '0')}:${_when.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.outfit(color: RastroColors.muted),
            ),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _when,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (date == null || !mounted) return;
              if (!context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_when),
              );
              if (time == null || !mounted) return;
              setState(() {
                _when = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: RastroColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Salvar alterações',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ),
          TextButton(
            onPressed: _delete,
            child: Text('Excluir gasto',
                style: GoogleFonts.outfit(color: RastroColors.danger)),
          ),
        ],
      ),
    );
  }
}
