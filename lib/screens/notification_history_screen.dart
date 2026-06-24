import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/notification_blocklist.dart';
import '../services/notification_debug_log.dart';
import '../theme/colors.dart';
import '../widgets/notification_entry_detail_sheet.dart';
import '../widgets/notification_log_list_tile.dart';
import 'notification_debug_screen.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _startSelection(String id) {
    setState(() {
      _selecting = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<NotificationDebugEntry> items) {
    setState(() {
      _selecting = true;
      _selectedIds
        ..clear()
        ..addAll(items.map((e) => e.id));
    });
  }

  void _deleteSelected(NotificationDebugLog log) {
    if (_selectedIds.isEmpty) return;
    log.removeByIds(Set<String>.from(_selectedIds));
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Itens removidos da lista')),
    );
  }

  Future<void> _blockSelectedPackages() async {
    final log = context.read<NotificationDebugLog>();
    final packages = log.entries
        .where((e) => _selectedIds.contains(e.id))
        .map((e) => e.packageName)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet();
    if (packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum pacote Android nos itens selecionados'),
        ),
      );
      return;
    }
    await context.read<NotificationBlocklist>().blockAll(packages);
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          packages.length == 1
              ? 'App bloqueado: ${packages.first}'
              : '${packages.length} apps bloqueados',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: RastroColors.base,
        appBar: AppBar(
          backgroundColor: RastroColors.base,
          elevation: 0,
          leading: _selecting
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: RastroColors.sub),
                  onPressed: _exitSelection,
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: RastroColors.sub, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text(
            _selecting
                ? '${_selectedIds.length} selecionado(s)'
                : 'Histórico de notificações',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: RastroColors.text,
            ),
          ),
          iconTheme: const IconThemeData(color: RastroColors.sub),
          actions: [
            if (_selecting) ...[
              IconButton(
                tooltip: 'Bloquear apps',
                icon: const Icon(Icons.block_rounded, color: RastroColors.danger),
                onPressed: _blockSelectedPackages,
              ),
              IconButton(
                tooltip: 'Excluir da lista',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: RastroColors.danger),
                onPressed: () =>
                    _deleteSelected(context.read<NotificationDebugLog>()),
              ),
            ] else ...[
              IconButton(
                tooltip: 'Apps bloqueados',
                icon: const Icon(Icons.block_rounded, color: RastroColors.sub),
                onPressed: () => showBlockedAppsSheet(context),
              ),
              IconButton(
                tooltip: 'Debug técnico',
                icon: const Icon(Icons.bug_report_outlined,
                    color: RastroColors.sub),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationDebugScreen(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.read<NotificationDebugLog>().clear(),
                child: Text(
                  'Limpar',
                  style: GoogleFonts.outfit(
                    color: RastroColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        body: Consumer2<NotificationDebugLog, NotificationBlocklist>(
          builder: (context, log, blocklist, _) {
            final items = log.entries.where((e) => !e.isSystem).toList();
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma notificação capturada ainda.\n\n'
                    'Com permissão ativa, os pushes dos apps aparecem aqui.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: RastroColors.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _selecting
                            ? _exitSelection
                            : () => _selectAll(items),
                        child: Text(
                          _selecting ? 'Cancelar seleção' : 'Selecionar todos',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: RastroColors.accent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${items.length} itens',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: RastroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final entry = items[i];
                      return NotificationLogListTile(
                        entry: entry,
                        selecting: _selecting,
                        selected: _selectedIds.contains(entry.id),
                        packageBlocked:
                            blocklist.isBlocked(entry.packageName),
                        onLongPress: () => _startSelection(entry.id),
                        onTap: () {
                          if (_selecting) {
                            _toggleSelection(entry.id);
                            return;
                          }
                          showNotificationEntryDetailSheet(context, entry);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
