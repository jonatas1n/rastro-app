import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import 'shared.dart';

// Maps category → color (mirrors the React prototype)
Color _catColor(TransactionCategory cat) => switch (cat) {
  TransactionCategory.alimentacao => RastroColors.catAlimentacao,
  TransactionCategory.transporte  => RastroColors.catTransporte,
  TransactionCategory.saude       => RastroColors.catSaude,
  TransactionCategory.compras     => RastroColors.catCompras,
  TransactionCategory.lazer       => RastroColors.catLazer,
  TransactionCategory.mercado     => RastroColors.catMercado,
  TransactionCategory.outros      => RastroColors.sub,
};

class TransactionItem extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  const TransactionItem({
    super.key,
    required this.tx,
    required this.onToggle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final essential = tx.isEssential;
    final cat       = tx.category;
    final color     = _catColor(cat);
    final time      = '${tx.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${tx.timestamp.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onToggle,
      onLongPress: onEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: essential ? RastroColors.card : RastroColors.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: essential ? RastroColors.borderMd : RastroColors.danger,
              width: 3,
            ),
            top: BorderSide(
              color: essential ? RastroColors.border : RastroColors.danger.withValues(alpha: 0.2),
              width: 1.5,
            ),
            right: BorderSide(
              color: essential ? RastroColors.border : RastroColors.danger.withValues(alpha: 0.2),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: essential ? RastroColors.border : RastroColors.danger.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            // Ícone
            CategoryChip(
              category: cat,
              catColor: essential ? color : RastroColors.danger,
            ),
            const SizedBox(width: 11),

            // Nome e categoria
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.place,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: essential ? RastroColors.text : RastroColors.muted,
                      decoration: essential ? null : TextDecoration.lineThrough,
                      decorationColor: RastroColors.danger.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cat.label} · $time',
                    style: GoogleFonts.dmSans(fontSize: 11, color: RastroColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Valor e badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: RastroColors.muted.withValues(alpha: 0.8)),
                  ),
                FmtValue(
                  amount:        tx.amount,
                  size:          15,
                  color:         essential ? RastroColors.text : RastroColors.danger,
                  strikethrough: !essential,
                ),
                const SizedBox(height: 3),
                Text(
                  essential ? 'Essencial' : 'Não-essencial',
                  style: GoogleFonts.dmSans(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: essential ? RastroColors.muted : RastroColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
