import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/finance_profile.dart';
import '../providers/finance_profile_provider.dart';
import '../theme/colors.dart';
import '../utils/br_money_input.dart';
import '../widgets/shared.dart';
import '../services/spending_summary_notification.dart';
import '../services/app_preferences.dart';

class FinanceSettingsScreen extends StatefulWidget {
  const FinanceSettingsScreen({super.key});

  @override
  State<FinanceSettingsScreen> createState() => _FinanceSettingsScreenState();
}

class _FinanceSettingsScreenState extends State<FinanceSettingsScreen> {
  final _incomeCtrl = TextEditingController();
  final _payDayCtrl = TextEditingController();
  final _cycleEndCtrl = TextEditingController();
  final _weeklyLimitCtrl = TextEditingController();
  final _monthlyLimitCtrl = TextEditingController();
  final _monthEndBalanceCtrl = TextEditingController();

  bool _weeklyOn = false;
  bool _monthlyOn = false;
  bool _monthEndOn = false;
  bool _saving = false;
  bool _persistentNotif = true;
  bool _loadingNotifPref = true;

  @override
  void initState() {
    super.initState();
    final p = context.read<FinanceProfileProvider>().profile;
    _fill(p);
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final on = await AppPreferences.persistentSpendingSummaryEnabled;
    if (!mounted) return;
    setState(() {
      _persistentNotif = on;
      _loadingNotifPref = false;
    });
  }

  void _fill(FinanceProfile p) {
    _incomeCtrl.text = p.monthlyIncome > 0
        ? formatBrMoneyInput(p.monthlyIncome)
        : '';
    _payDayCtrl.text = '${p.payDay}';
    _cycleEndCtrl.text = '${p.cycleEndDay}';
    _weeklyOn = p.weeklyLimitEnabled;
    _monthlyOn = p.monthlyLimitEnabled;
    _monthEndOn = p.monthEndBalanceEnabled;
    _weeklyLimitCtrl.text = p.weeklySpendingLimit != null
        ? formatBrMoneyInput(p.weeklySpendingLimit!)
        : '';
    _monthlyLimitCtrl.text = p.monthlySpendingLimit != null
        ? formatBrMoneyInput(p.monthlySpendingLimit!)
        : '';
    _monthEndBalanceCtrl.text = p.monthEndTargetBalance != null
        ? formatBrMoneyInput(p.monthEndTargetBalance!)
        : '';
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _payDayCtrl.dispose();
    _cycleEndCtrl.dispose();
    _weeklyLimitCtrl.dispose();
    _monthlyLimitCtrl.dispose();
    _monthEndBalanceCtrl.dispose();
    super.dispose();
  }

  int _parseDay(String raw, int fallback) {
    final v = int.tryParse(raw.trim());
    if (v == null) return fallback;
    return v.clamp(1, 31);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = FinanceProfile(
      monthlyIncome: parseBrMoney(_incomeCtrl.text) ?? 0,
      payDay: _parseDay(_payDayCtrl.text, 1),
      cycleEndDay: _parseDay(_cycleEndCtrl.text, 31),
      weeklyLimitEnabled: _weeklyOn,
      weeklySpendingLimit:
          _weeklyOn ? parseBrMoney(_weeklyLimitCtrl.text) : null,
      monthlyLimitEnabled: _monthlyOn,
      monthlySpendingLimit:
          _monthlyOn ? parseBrMoney(_monthlyLimitCtrl.text) : null,
      monthEndBalanceEnabled: _monthEndOn,
      monthEndTargetBalance:
          _monthEndOn ? parseBrMoney(_monthEndBalanceCtrl.text) : null,
    );
    await context.read<FinanceProfileProvider>().save(profile);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RastroColors.base,
      appBar: AppBar(
        backgroundColor: RastroColors.base,
        elevation: 0,
        title: Text('Renda e metas',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700, color: RastroColors.text)),
        iconTheme: const IconThemeData(color: RastroColors.sub),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionLabel(title: 'Renda'),
          _Field(
            label: 'Quanto você ganha por mês (R\$)',
            controller: _incomeCtrl,
            isMoney: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Dia que recebe',
                  controller: _payDayCtrl,
                  keyboard: TextInputType.number,
                  hint: 'Ex.: 5',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'Fim do ciclo (dia)',
                  controller: _cycleEndCtrl,
                  keyboard: TextInputType.number,
                  hint: 'Ex.: 4',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ex.: recebe dia 5 e o ciclo fecha dia 4 do mês seguinte.',
            style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.muted),
          ),
          const SizedBox(height: 20),
          SectionLabel(title: 'Metas de gasto'),
          _GoalToggle(
            title: 'Teto semanal',
            subtitle: 'Alerta quando passar do limite na semana',
            value: _weeklyOn,
            onChanged: (v) => setState(() => _weeklyOn = v),
            child: _Field(
              label: 'Gasto máximo / semana (R\$)',
              controller: _weeklyLimitCtrl,
              isMoney: true,
            ),
          ),
          const SizedBox(height: 10),
          _GoalToggle(
            title: 'Teto no ciclo',
            subtitle: 'Limite de gastos no período entre recebimentos',
            value: _monthlyOn,
            onChanged: (v) => setState(() => _monthlyOn = v),
            child: _Field(
              label: 'Gasto máximo no ciclo (R\$)',
              controller: _monthlyLimitCtrl,
              isMoney: true,
            ),
          ),
          const SizedBox(height: 10),
          _GoalToggle(
            title: 'Saldo alvo no fim do ciclo',
            subtitle: 'Quanto quer sobrar quando o ciclo fechar',
            value: _monthEndOn,
            onChanged: (v) => setState(() => _monthEndOn = v),
            child: _Field(
              label: 'Quero terminar com (R\$)',
              controller: _monthEndBalanceCtrl,
              isMoney: true,
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel(title: 'Notificações'),
          RastroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Resumo fixo na barra',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
              subtitle: Text(
                'Mostra gastos e metas. Deslizar não remove — desative aqui.',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: RastroColors.muted,
                ),
              ),
              value: _persistentNotif,
              onChanged: _loadingNotifPref
                  ? null
                  : (v) async {
                      setState(() => _persistentNotif = v);
                      await SpendingSummaryNotification.setEnabled(v);
                    },
              activeColor: RastroColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: RastroColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Salvar',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final String? hint;
  final bool isMoney;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboard,
    this.hint,
    this.isMoney = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isMoney ? TextInputType.number : keyboard,
      inputFormatters: isMoney ? [BrMoneyInputFormatter()] : null,
      style: GoogleFonts.dmSans(color: RastroColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.dmSans(color: RastroColors.muted, fontSize: 12),
        hintStyle: GoogleFonts.dmSans(color: RastroColors.muted),
        filled: true,
        fillColor: RastroColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RastroColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RastroColors.border),
        ),
      ),
    );
  }
}

class _GoalToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  const _GoalToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RastroCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            color: RastroColors.text)),
                    Text(subtitle,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: RastroColors.muted)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: RastroColors.accent,
              ),
            ],
          ),
          if (value) ...[const SizedBox(height: 10), child],
        ],
      ),
    );
  }
}
