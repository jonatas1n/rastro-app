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
import '../services/spending_insight_prefs.dart';
import '../providers/app_lock_provider.dart';

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
  bool _transactionAlert = true;
  bool _loadingNotifPref = true;
  bool _insightAlerts = true;
  bool _dailySummary22 = true;
  bool _loadingInsightPrefs = true;
  bool _appLock = false;
  bool _loadingAppLock = true;

  @override
  void initState() {
    super.initState();
    final p = context.read<FinanceProfileProvider>().profile;
    _fill(p);
    _loadNotifPref();
    _loadInsightPrefs();
    _loadAppLockPref();
  }

  Future<void> _loadAppLockPref() async {
    await context.read<AppLockProvider>().refreshDeviceAuthAvailability();
    if (!mounted) return;
    final lock = context.read<AppLockProvider>();
    setState(() {
      _appLock = lock.enabled;
      _loadingAppLock = false;
    });
  }

  Future<void> _loadInsightPrefs() async {
    final alerts = await SpendingInsightPrefs.insightsEnabled;
    final summary = await SpendingInsightPrefs.dailySummaryAt22Enabled;
    if (!mounted) return;
    setState(() {
      _insightAlerts = alerts;
      _dailySummary22 = summary;
      _loadingInsightPrefs = false;
    });
  }

  Future<void> _loadNotifPref() async {
    final on = await AppPreferences.persistentSpendingSummaryEnabled;
    final txAlert = await AppPreferences.transactionAlertEnabled;
    if (!mounted) return;
    setState(() {
      _persistentNotif = on;
      _transactionAlert = txAlert;
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
    final syncErr =
        await context.read<FinanceProfileProvider>().save(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (syncErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncErr),
          backgroundColor: RastroColors.danger,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RastroColors.base,
      appBar: AppBar(
        backgroundColor: RastroColors.base,
        elevation: 0,
        title: Text('Renda e metas',
            style: GoogleFonts.outfit(
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
            style: GoogleFonts.outfit(fontSize: 11, color: RastroColors.muted),
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
                'Aviso a cada gasto',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
              subtitle: Text(
                'Notifica cada compra detectada, com botões para marcar como essencial ou descartar.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: RastroColors.muted,
                ),
              ),
              value: _transactionAlert,
              onChanged: _loadingNotifPref
                  ? null
                  : (v) async {
                      setState(() => _transactionAlert = v);
                      await AppPreferences.setTransactionAlertEnabled(v);
                    },
              activeColor: RastroColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          RastroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Resumo fixo na barra',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
              subtitle: Text(
                'Mostra gastos e metas. Deslizar não remove — desative aqui.',
                style: GoogleFonts.outfit(
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
          const SizedBox(height: 10),
          RastroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Alertas de ritmo',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
              subtitle: Text(
                'Aviso quando gastos sobem ou descem muito (máx. 1/dia).',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: RastroColors.muted,
                ),
              ),
              value: _insightAlerts,
              onChanged: _loadingInsightPrefs
                  ? null
                  : (v) async {
                      setState(() => _insightAlerts = v);
                      await SpendingInsightPrefs.setInsightsEnabled(v);
                    },
              activeColor: RastroColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          RastroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Resumo às 22h',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
              subtitle: Text(
                'Notificação diária com total do dia vs sua média recente.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: RastroColors.muted,
                ),
              ),
              value: _dailySummary22,
              onChanged: _loadingInsightPrefs
                  ? null
                  : (v) async {
                      setState(() => _dailySummary22 = v);
                      await SpendingInsightPrefs.setDailySummaryAt22Enabled(v);
                    },
              activeColor: RastroColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          SectionLabel(title: 'Segurança'),
          Builder(
            builder: (context) {
              final lockProv = context.watch<AppLockProvider>();
              final canUse = lockProv.deviceAuthAvailable;
              return RastroCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Bloqueio do app',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: RastroColors.text,
                    ),
                  ),
                  subtitle: Text(
                    canUse
                        ? 'Exigir senha ou digital para abrir o app.'
                        : 'Configure um PIN, padrão ou digital nas configurações do Android para usar esta opção.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: RastroColors.muted,
                    ),
                  ),
                  value: _appLock,
                  onChanged: _loadingAppLock || !canUse || lockProv.authenticating
                      ? null
                      : (v) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final result = await lockProv.setEnabled(v);
                          if (!mounted) return;
                          if (result == AppLockToggleResult.success) {
                            setState(() => _appLock = v);
                            return;
                          }
                          if (result == AppLockToggleResult.authFailed) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Não foi possível confirmar sua identidade.',
                                  style: GoogleFonts.outfit(),
                                ),
                              ),
                            );
                            return;
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Este dispositivo não tem bloqueio de tela configurado.',
                                style: GoogleFonts.outfit(),
                              ),
                            ),
                          );
                        },
                  activeColor: RastroColors.accent,
                ),
              );
            },
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
                      style: GoogleFonts.outfit(
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
      style: GoogleFonts.outfit(color: RastroColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.outfit(color: RastroColors.muted, fontSize: 12),
        hintStyle: GoogleFonts.outfit(color: RastroColors.muted),
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
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: RastroColors.text)),
                    Text(subtitle,
                        style: GoogleFonts.outfit(
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
