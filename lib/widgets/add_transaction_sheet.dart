import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/finance_profile_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/spending_summary_notification.dart';
import '../theme/colors.dart';
import '../utils/br_money_input.dart';

enum ManualPaymentKind {
  cash,
  untrackedCard,
  other,
}

extension ManualPaymentKindX on ManualPaymentKind {
  String get label => switch (this) {
        ManualPaymentKind.cash => 'Dinheiro vivo',
        ManualPaymentKind.untrackedCard => 'Cartão sem notificação',
        ManualPaymentKind.other => 'Outro não rastreado',
      };

  String get emoji => switch (this) {
        ManualPaymentKind.cash => '💵',
        ManualPaymentKind.untrackedCard => '💳',
        ManualPaymentKind.other => '📝',
      };

  String get rawTag => switch (this) {
        ManualPaymentKind.cash => 'manual:dinheiro_vivo',
        ManualPaymentKind.untrackedCard => 'manual:cartao_sem_notificacao',
        ManualPaymentKind.other => 'manual:outro',
      };

  String get placeHint => switch (this) {
        ManualPaymentKind.cash => 'Ex.: feira, padaria, ônibus',
        ManualPaymentKind.untrackedCard => 'Ex.: loja, restaurante',
        ManualPaymentKind.other => 'Descreva o gasto',
      };
}

Future<void> showAddTransactionSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RastroColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _AddTransactionSheet(),
  );
}

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet();

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _placeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  ManualPaymentKind _paymentKind = ManualPaymentKind.cash;
  TransactionCategory _category = TransactionCategory.outros;
  bool _essential = true;
  DateTime _when = DateTime.now();
  bool _saving = false;

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
        const SnackBar(content: Text('Informe descrição e valor válidos')),
      );
      return;
    }

    setState(() => _saving = true);

    final tx = Transaction(
      place: _placeCtrl.text.trim(),
      amount: amount,
      category: _category,
      timestamp: _when,
      isEssential: _essential,
      rawNotification: _paymentKind.rawTag,
    );

    final txProv = context.read<TransactionProvider>();
    final finProv = context.read<FinanceProfileProvider>();
    await txProv.addTransaction(tx);
    await finProv.refreshSpending();
    await SpendingSummaryNotification.refresh();

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gasto registrado · ${_paymentKind.label}')),
    );
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adicionar gasto',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: RastroColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Para dinheiro vivo e compras que o banco não notifica.',
              style: GoogleFonts.outfit(fontSize: 12, color: RastroColors.muted),
            ),
            const SizedBox(height: 14),
            Text(
              'Forma de pagamento',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RastroColors.sub,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ManualPaymentKind.values.map((kind) {
                final selected = _paymentKind == kind;
                return ChoiceChip(
                  label: Text('${kind.emoji} ${kind.label}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _paymentKind = kind),
                  selectedColor: RastroColors.accent.withValues(alpha: 0.25),
                  backgroundColor: RastroColors.card,
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? RastroColors.text : RastroColors.sub,
                  ),
                  side: BorderSide(
                    color: selected ? RastroColors.accent : RastroColors.border,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _placeCtrl,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.outfit(color: RastroColors.text),
              decoration: InputDecoration(
                labelText: 'Local / descrição',
                hintText: _paymentKind.placeHint,
              ),
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
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.emoji} ${c.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Essencial',
                style: GoogleFonts.outfit(color: RastroColors.text),
              ),
              value: _essential,
              activeColor: RastroColors.accent,
              onChanged: (v) => setState(() => _essential = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Data e hora',
                style: GoogleFonts.outfit(color: RastroColors.text),
              ),
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
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Registrar gasto',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
