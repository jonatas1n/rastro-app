import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_lock_provider.dart';
import '../theme/colors.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptUnlock());
  }

  Future<void> _promptUnlock() async {
    if (!mounted) return;
    await context.read<AppLockProvider>().tryUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();

    return Scaffold(
      backgroundColor: RastroColors.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/logo.svg', width: 72),
              const SizedBox(height: 32),
              Text(
                'Rastro bloqueado',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: RastroColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Use a digital ou o PIN do dispositivo para continuar.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: RastroColors.muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: lock.authenticating ? null : _promptUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RastroColors.accent,
                    disabledBackgroundColor:
                        RastroColors.accent.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: lock.authenticating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Desbloquear',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exibe [child] quando desbloqueado; caso contrário, [AppLockScreen].
class AppLockGate extends StatelessWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();

    if (!lock.initialized) {
      return const SizedBox.shrink();
    }

    if (lock.enabled && lock.locked) {
      return const AppLockScreen();
    }

    return child;
  }
}
