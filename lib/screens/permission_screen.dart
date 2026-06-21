import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';

class PermissionScreen extends StatelessWidget {
  final VoidCallback onGranted;
  const PermissionScreen({super.key, required this.onGranted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RastroColors.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('👁', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 24),
              Text('Rastro precisa ver suas notificações',
                  style: GoogleFonts.dmSans(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: RastroColors.text, height: 1.2)),
              const SizedBox(height: 16),
              Text(
                'Para registrar seus gastos automaticamente, o Rastro lê as '
                'notificações dos seus aplicativos bancários.\n\n'
                'Nenhum dado é enviado para servidores. '
                'Tudo fica armazenado apenas no seu celular.',
                style: GoogleFonts.dmSans(fontSize: 14, color: RastroColors.sub, height: 1.6),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await NotificationService.requestPermission();
                    await NotificationService.init();
                    onGranted();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RastroColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Permitir acesso',
                      style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
