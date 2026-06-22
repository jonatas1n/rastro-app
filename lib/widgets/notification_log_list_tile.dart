import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/notification_debug_log.dart';
import '../theme/colors.dart';

class NotificationLogListTile extends StatelessWidget {
  final NotificationDebugEntry entry;
  final bool selecting;
  final bool selected;
  final bool packageBlocked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const NotificationLogListTile({
    super.key,
    required this.entry,
    this.selecting = false,
    this.selected = false,
    this.packageBlocked = false,
    required this.onTap,
    this.onLongPress,
  });

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

    final borderColor = selected
        ? RastroColors.accent
        : packageBlocked
            ? RastroColors.muted.withValues(alpha: 0.5)
            : RastroColors.border;

    return Material(
      color: selected
          ? RastroColors.accent.withValues(alpha: 0.08)
          : RastroColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: selected ? RastroColors.accent : RastroColors.muted,
                  ),
                ),
              Expanded(
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
                        if (packageBlocked)
                          Text(
                            'BLOQUEADO',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: RastroColors.muted,
                            ),
                          ),
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
    );
  }
}
