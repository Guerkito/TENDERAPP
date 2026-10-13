import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/supabase_service.dart';
import '../constants/app_theme.dart';

/// Pantalla de bienvenida: iniciar sesión o crear cuenta.
/// Conecta la tienda con el sistema de tarjetas de fidelización.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoggedIn;

  const LoginScreen({super.key, this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { login, signup }

class _LoginScreenState extends State<LoginScreen> {
  static const Color _green = Color(0xFF143122);
  static const Color _neon = Color(0xFFC6F24E);
  static const Color _grey = Color(0xFF5F6B63);
  static const Color _errorRed = Color(0xFFC0392B);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  String? _pendingEmail; // Cuenta creada, pendiente de confirmar por correo

  bool get _isLogin => _mode == _AuthMode.login;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_busy || mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      _pendingEmail = null;
      _confirmController.clear();
    });
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Escribe tu correo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Escribe un correo válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Escribe tu contraseña';
    if (!_isLogin && password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    setState(() => _busy = true);
    try {
      // Si la app arrancó sin internet, reintentamos conectar aquí.
      if (!SupabaseService.isReady) await SupabaseService.init();

      if (_isLogin) {
        await SupabaseService.signIn(email, _passwordController.text);
        // Permite que el gestor de contraseñas ofrezca guardar la credencial.
        TextInput.finishAutofillContext();
        widget.onLoggedIn?.call();
      } else {
        final active =
            await SupabaseService.signUp(email, _passwordController.text);
        TextInput.finishAutofillContext();
        if (!mounted) return;
        if (active) {
          widget.onLoggedIn?.call();
        } else {
          setState(() {
            _pendingEmail = email;
            _passwordController.clear();
            _confirmController.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendConfirmation() async {
    if (_busy || _pendingEmail == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.resendConfirmation(_pendingEmail!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Correo reenviado. Revisa tu bandeja y el spam.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('ENVIAR ENLACE')),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;

    if (_validateEmail(email) != null) {
      setState(() => _error =
          'Escribe un correo válido, por ejemplo: nombre@correo.com');
      return;
    }

    // shortcut: el enlace abre la webapp cuando esté publicada; hasta
    // entonces, soporte restablece la contraseña a mano.
    setState(() => _busy = true);
    try {
      await SupabaseService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Si ese correo tiene cuenta, te llegará el enlace para crear una contraseña nueva. Revisa también el spam.')));
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Traduce los errores del servidor a mensajes que el tendero entienda.
  String _friendlyError(Object e) {
    debugPrint('LoginScreen: error de autenticación: $e');
    if (e is SocketException || e is AuthRetryableFetchException) {
      return 'Sin conexión a internet. Revisa tu red e inténtalo de nuevo.';
    }
    final m = (e is AuthException ? e.message : e.toString()).toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Tu correo aún no está confirmado. Abre el enlace que te enviamos (revisa el spam).';
    }
    if (m.contains('already registered') || m.contains('already been')) {
      return 'Ya existe una cuenta con ese correo. Mejor inicia sesión.';
    }
    if (m.contains('at least 6') ||
        m.contains('weak password') ||
        m.contains('password should')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (m.contains('unable to validate email') || m.contains('invalid format')) {
      return 'Escribe un correo válido, por ejemplo: nombre@correo.com';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo otra vez.';
    }
    if (m.contains('failed host lookup') ||
        m.contains('socket') ||
        m.contains('network')) {
      return 'Sin conexión a internet. Revisa tu red e inténtalo de nuevo.';
    }
    return 'No pudimos completar la operación. Revisa tu internet e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(),
                  const SizedBox(height: 24),
                  if (_pendingEmail != null)
                    _buildConfirmationCard()
                  else
                    _buildAuthCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                semanticLabel: 'Logo de TenderApp',
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  color: _green,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'TenderApp',
            style: AppText.displayOnDark.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu tienda y la fidelización de tus clientes,\nen un solo lugar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(
                      value: _AuthMode.login, label: Text('Ingresar')),
                  ButtonSegment(
                      value: _AuthMode.signup, label: Text('Crear cuenta')),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    _switchMode(selection.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.lime
                          : Colors.white),
                  foregroundColor: const WidgetStatePropertyAll(_green),
                  side: const WidgetStatePropertyAll(
                      BorderSide(color: Color(0xFFE3E6EA))),
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) _buildErrorBanner(_error!),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
                decoration: _inputDecoration(
                  label: 'Correo electrónico',
                  hint: 'Ej: maria@correo.com',
                  icon: Icons.mail_outline,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                textInputAction:
                    _isLogin ? TextInputAction.done : TextInputAction.next,
                autofillHints: [
                  _isLogin ? AutofillHints.password : AutofillHints.newPassword
                ],
                validator: _validatePassword,
                onFieldSubmitted: _isLogin ? (_) => _submit() : null,
                decoration: _inputDecoration(
                  label: 'Contraseña',
                  helper: _isLogin ? null : 'Mínimo 6 caracteres',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    tooltip:
                        _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _grey,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validateConfirm,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _inputDecoration(
                    label: 'Repite la contraseña',
                    icon: Icons.lock_outline,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: _green,
                  disabledBackgroundColor: _neon.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _green),
                      )
                    : Text(
                        _isLogin ? 'ENTRAR A MI TIENDA' : 'CREAR MI CUENTA',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
              const SizedBox(height: 10),
              if (_isLogin)
                TextButton(
                  onPressed: _busy ? null : _showForgotPasswordDialog,
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                        color: _grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _switchMode(
                        _isLogin ? _AuthMode.signup : _AuthMode.login),
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Crear cuenta'
                      : '¿Ya tienes cuenta? Ingresar',
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _neon.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                color: _green, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Revisa tu correo',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _green),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: 'Enviamos un enlace de confirmación a ',
              children: [
                TextSpan(
                  text: _pendingEmail,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: _green),
                ),
                const TextSpan(
                    text:
                        '. Ábrelo desde tu celular y vuelve aquí para entrar.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _grey, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Si no lo ves, revisa la carpeta de spam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_error != null) _buildErrorBanner(_error!),
          FilledButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _pendingEmail = null;
                      _mode = _AuthMode.login;
                      _error = null;
                    }),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: _green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('YA CONFIRMÉ, IR A INGRESAR',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : _resendConfirmation,
            icon: const Icon(Icons.refresh, size: 18, color: _green),
            label: const Text('Reenviar correo',
                style: TextStyle(color: _green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _errorRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: _errorRed, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon, color: _grey),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFAFBFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE3E6EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE3E6EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _neon, width: 1.6),
      ),
    );
  }
}
