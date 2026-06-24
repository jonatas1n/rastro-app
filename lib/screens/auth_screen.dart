import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;

  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _name     = TextEditingController();

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();

    final ok = _isLogin
        ? await auth.login(_email.text.trim(), _password.text)
        : await auth.register(_email.text.trim(), _password.text, _name.text.trim());

    if (mounted) setState(() => _loading = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Erro'),
          backgroundColor: RastroColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RastroColors.base,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              SvgPicture.asset('assets/logo.svg', width: 88),
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'Bem-vindo de volta' : 'Criar conta',
                style: GoogleFonts.outfit(
                    fontSize: 26, fontWeight: FontWeight.w800, color: RastroColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Rastro — seu rastro financeiro',
                style: GoogleFonts.outfit(fontSize: 14, color: RastroColors.muted),
              ),
              const SizedBox(height: 36),

              if (!_isLogin) ...[
                _Field(controller: _name, label: 'Nome', hint: 'Como quer ser chamado'),
                const SizedBox(height: 14),
              ],
              _Field(controller: _email,    label: 'Email',    hint: 'seu@email.com', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _Field(controller: _password, label: 'Senha',    hint: '••••••••', obscure: true),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RastroColors.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: RastroColors.accent.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(_isLogin ? 'Entrar' : 'Criar conta',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Não tem conta? Criar agora' : 'Já tenho conta',
                    style: GoogleFonts.outfit(fontSize: 13, color: RastroColors.sub),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final bool   obscure;
  final TextInputType keyboard;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure  = false,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600,
                color: RastroColors.sub)),
        const SizedBox(height: 6),
        TextField(
          controller:   controller,
          obscureText:  obscure,
          keyboardType: keyboard,
          style: GoogleFonts.outfit(fontSize: 14, color: RastroColors.text),
          decoration: InputDecoration(
            hintText:        hint,
            hintStyle:       GoogleFonts.outfit(color: RastroColors.muted),
            filled:          true,
            fillColor:       RastroColors.surface,
            contentPadding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border:          OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: RastroColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: RastroColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: RastroColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
