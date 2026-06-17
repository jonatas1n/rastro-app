import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/messages_provider.dart';
import '../services/api_client.dart';
import '../theme/colors.dart';

class MessagesSheet extends StatelessWidget {
  const MessagesSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RastroColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const MessagesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MessagesProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: RastroColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mensagens',
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700,
                      color: RastroColors.text)),
              if (prov.unreadCount > 0)
                TextButton(
                  onPressed: prov.acknowledgeAll,
                  child: Text('Marcar tudo como lido',
                      style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.accent)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (prov.messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('Nenhuma mensagem ainda',
                  style: GoogleFonts.dmSans(fontSize: 13, color: RastroColors.muted)),
            )
          else
            ...prov.messages.map((msg) => _MessageTile(msg: msg)),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final ContextMessage msg;
  const _MessageTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<MessagesProvider>().acknowledge(msg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.opened ? RastroColors.card : RastroColors.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: msg.opened ? RastroColors.border : RastroColors.accent.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.opened)
              Container(
                width: 7, height: 7, margin: const EdgeInsets.only(top: 5, right: 10),
                decoration: const BoxDecoration(
                  color: RastroColors.accent, shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                msg.message,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: msg.opened ? RastroColors.sub : RastroColors.text,
                  fontWeight: msg.opened ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de notificação para o header
class MessagesBadge extends StatelessWidget {
  const MessagesBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<MessagesProvider>().unreadCount;

    return GestureDetector(
      onTap: () => MessagesSheet.show(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, color: RastroColors.sub, size: 22),
          if (count > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                    color: RastroColors.accent, shape: BoxShape.circle),
                child: Center(
                  child: Text('$count',
                      style: GoogleFonts.dmSans(
                          fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
