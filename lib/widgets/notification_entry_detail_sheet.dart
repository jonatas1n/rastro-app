import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/notification_blocklist.dart';
import '../services/notification_debug_log.dart';
import '../theme/colors.dart';
import 'shared.dart';

void showNotificationEntryDetailSheet(
  BuildContext context,
  NotificationDebugEntry entry,
) {
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
      builder: (_, scrollCtrl) => Consumer<NotificationBlocklist>(
        builder: (context, blocklist, _) {
          final pkg = entry.packageName;
          final blocked = blocklist.isBlocked(pkg);
          return Padding(
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
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: RastroColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                const SectionLabel(title: 'Critérios'),
                ...entry.checks.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          c.ok
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 18,
                          color:
                              c.ok ? RastroColors.safe : RastroColors.danger,
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
                const SectionLabel(title: 'Pacote'),
                SelectableText(
                  entry.packageName ?? '(null)',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: RastroColors.sub,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionLabel(title: 'Título'),
                SelectableText(
                  entry.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RastroColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                const SectionLabel(title: 'Texto'),
                SelectableText(
                  entry.body,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RastroColors.sub,
                  ),
                ),
                const SizedBox(height: 16),
                if (pkg != null && pkg.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (blocked) {
                          await blocklist.unblock(pkg);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Desbloqueado: $pkg')),
                            );
                          }
                        } else {
                          await blocklist.block(pkg);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('App bloqueado: $pkg')),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        blocked
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                        size: 18,
                      ),
                      label: Text(
                        blocked ? 'Desbloquear app' : 'Bloquear app',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context
                          .read<NotificationDebugLog>()
                          .removeByIds({entry.id});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removido da lista')),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Excluir da lista'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final buf = StringBuffer()
                        ..writeln('package: ${entry.packageName}')
                        ..writeln('title: ${entry.title}')
                        ..writeln('body: ${entry.body}')
                        ..writeln(
                          'checks: ${entry.passedCount}/${entry.totalCount}',
                        );
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
          );
        },
      ),
    ),
  );
}

void showBlockedAppsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RastroColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => Consumer<NotificationBlocklist>(
        builder: (context, blocklist, _) {
          final blocked = blocklist.blocked.toList()..sort();
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                'Apps bloqueados',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: RastroColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Notificações destes pacotes não entram no parser nem geram gastos.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RastroColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (blocked.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhum app bloqueado.\n'
                    'Selecione itens na lista e toque em bloquear, '
                    'ou use “Bloquear app” no detalhe.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: RastroColors.muted,
                      height: 1.5,
                    ),
                  ),
                )
              else
                ...blocked.map(
                  (pkg) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      pkg,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: RastroColors.text,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => blocklist.unblock(pkg),
                      child: Text(
                        'Desbloquear',
                        style: GoogleFonts.dmSans(
                          color: RastroColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
