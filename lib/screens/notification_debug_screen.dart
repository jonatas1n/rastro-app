import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/notification_debug_log.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';
import '../widgets/shared.dart';
import 'notification_history_screen.dart';

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() =>
      _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  Map<String, bool>? _diag;
  bool _generatingTest = false;

  @override
  void initState() {
    super.initState();
    _refreshDiag();
    NotificationService.reconnect();
  }

  Future<void> _refreshDiag() async {
    final d = await NotificationService.diagnostics;
    if (mounted) setState(() => _diag = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RastroColors.base,
      appBar: AppBar(
        backgroundColor: RastroColors.base,
        elevation: 0,
        title: Text(
          'Debug de notificações',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            color: RastroColors.text,
          ),
        ),
        iconTheme: const IconThemeData(color: RastroColors.sub),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: RastroColors.sub),
            onPressed: () async {
              await NotificationService.reconnect();
              await _refreshDiag();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          _StatusPanel(diag: _diag),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _generatingTest
                ? null
                : () async {
                    setState(() => _generatingTest = true);
                    try {
                      await NotificationService.triggerDebugTestNotification();
                    } finally {
                      if (mounted) setState(() => _generatingTest = false);
                    }
                  },
            icon: _generatingTest
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RastroColors.base,
                    ),
                  )
                : const Icon(Icons.science_outlined, size: 20),
            label: Text(
              'Gerar notificação de teste',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: RastroColors.accent,
              foregroundColor: RastroColors.base,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationHistoryScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_outlined, size: 20),
            label: const Text('Abrir histórico de notificações'),
          ),
          const SizedBox(height: 24),
          SectionLabel(title: 'Diagnósticos recentes'),
          const SizedBox(height: 8),
          Consumer<NotificationDebugLog>(
            builder: (context, log, _) {
              final system = log.entries.where((e) => e.isSystem).take(8);
              if (system.isEmpty) {
                return Text(
                  'Nenhum diagnóstico registrado.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RastroColors.muted,
                  ),
                );
              }
              return Column(
                children: system
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RastroCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  color: RastroColors.text,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.body,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: RastroColors.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final Map<String, bool>? diag;
  const _StatusPanel({required this.diag});

  @override
  Widget build(BuildContext context) {
    final d = diag;
    return RastroCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado do listener',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: RastroColors.text,
            ),
          ),
          const SizedBox(height: 8),
          if (d == null)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ...d.entries.map(
              (e) => _StatusRow(label: e.key, ok: e.value),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ok;
  const _StatusRow({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 14,
            color: ok ? RastroColors.safe : RastroColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.sub),
            ),
          ),
        ],
      ),
    );
  }
}
