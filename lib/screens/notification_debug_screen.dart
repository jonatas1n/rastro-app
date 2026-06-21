import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/notification_debug_log.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';
import '../widgets/shared.dart';

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
          TextButton(
            onPressed: () => context.read<NotificationDebugLog>().clear(),
            child: Text(
              'Limpar',
              style: GoogleFonts.dmSans(
                color: RastroColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<NotificationDebugLog>(
        builder: (context, log, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusPanel(diag: _diag),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: FilledButton.icon(
                  onPressed: _generatingTest
                      ? null
                      : () async {
                          setState(() => _generatingTest = true);
                          try {
                            await NotificationService.triggerDebugTestNotification();
                          } finally {
                            if (mounted) {
                              setState(() => _generatingTest = false);
                            }
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
              ),
              Expanded(
                child: log.entries.where((e) => !e.isSystem).isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            log.entries.any((e) => e.isSystem)
                                ? 'Ponte configurada, mas nenhuma notificação '
                                    'chegou ainda.\n\n'
                                    'Confira permissão e serviço acima, ou use '
                                    '"Gerar notificação de teste".'
                                : 'Nada capturado ainda.\n\n'
                                    'Use o botão de teste ou toque ↻ para '
                                    'reconectar a ponte.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: RastroColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                        itemCount: log.entries.where((e) => !e.isSystem).length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final items =
                              log.entries.where((e) => !e.isSystem).toList();
                          return _EntryTile(entry: items[i]);
                        },
                      ),
              ),
            ],
          );
        },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: RastroCard(
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

class _EntryTile extends StatelessWidget {
  final NotificationDebugEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm:ss').format(entry.at);
    final title = entry.title.trim().isEmpty ? '(sem título)' : entry.title;
    final subtitle = entry.packageName ?? 'pacote desconhecido';
    final scoreColor = entry.saved
        ? RastroColors.safe
        : entry.passedCount == entry.totalCount
            ? RastroColors.accent
            : RastroColors.danger;

    return Material(
      color: RastroColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showDetail(context, entry),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RastroColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$time · ${entry.passedCount}/${entry.totalCount}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                  const Spacer(),
                  if (entry.saved)
                    Text(
                      'SALVO',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: RastroColors.safe,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  color: RastroColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, NotificationDebugEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RastroColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RastroColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${entry.passedCount} de ${entry.totalCount} critérios',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: RastroColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm:ss').format(entry.at),
                style: GoogleFonts.dmSans(fontSize: 12, color: RastroColors.muted),
              ),
              const SizedBox(height: 16),
              SectionLabel(title: 'Critérios'),
              ...entry.checks.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        c.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 18,
                        color: c.ok ? RastroColors.safe : RastroColors.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.label,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                color: RastroColors.text,
                              ),
                            ),
                            if (c.detail != null && c.detail!.isNotEmpty)
                              Text(
                                c.detail!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: RastroColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionLabel(title: 'Pacote'),
              SelectableText(
                entry.packageName ?? '(null)',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RastroColors.sub,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              SectionLabel(title: 'Título'),
              SelectableText(
                entry.title,
                style: GoogleFonts.dmSans(fontSize: 13, color: RastroColors.text),
              ),
              const SizedBox(height: 12),
              SectionLabel(title: 'Texto'),
              SelectableText(
                entry.body,
                style: GoogleFonts.dmSans(fontSize: 13, color: RastroColors.sub),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final buf = StringBuffer()
                      ..writeln('package: ${entry.packageName}')
                      ..writeln('title: ${entry.title}')
                      ..writeln('body: ${entry.body}')
                      ..writeln('checks: ${entry.passedCount}/${entry.totalCount}');
                    for (final c in entry.checks) {
                      buf.writeln(
                        '  ${c.ok ? '✓' : '✗'} ${c.label}${c.detail != null ? ': ${c.detail}' : ''}',
                      );
                    }
                    Clipboard.setData(ClipboardData(text: buf.toString()));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Copiado')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar para montar regex'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
