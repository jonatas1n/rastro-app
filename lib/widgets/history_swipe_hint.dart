import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/colors.dart';

/// Dica lateral de que o dashboard pode ser arrastado para o histórico.
class HistorySwipeHint extends StatefulWidget {
  const HistorySwipeHint({super.key});

  @override
  State<HistorySwipeHint> createState() => _HistorySwipeHintState();
}

class _HistorySwipeHintState extends State<HistorySwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) {
          final dx = -4 + _bounce.value * 8;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: RastroColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RastroColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: RastroColors.accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Arraste para o histórico',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: RastroColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
