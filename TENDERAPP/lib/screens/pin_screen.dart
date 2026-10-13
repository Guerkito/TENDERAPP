import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class PinScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinScreen({super.key, required this.onSuccess});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  String _errorMsg = '';
  int _failedAttempts = 0;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _errorMsg = '';
    });
    if (_entered.length == 4) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _verify() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.verifyPin(_entered)) {
      widget.onSuccess();
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _entered = '';
        _errorMsg = 'PIN incorrecto';
        _failedAttempts++;
      });
    }
  }

  /// Escape del candado: tras 3 intentos, desactivar el PIN confirmando el
  /// nombre del negocio (los datos locales no se pierden nunca).
  Future<void> _forgotPin() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Desactivar PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para desactivar el PIN, escribe el nombre exacto de tu negocio.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del negocio',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DESACTIVAR')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (controller.text.trim().toLowerCase() ==
        settings.storeName.trim().toLowerCase()) {
      await settings.removePin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'PIN desactivado. Puedes configurarlo de nuevo en Más → PIN de Seguridad.')));
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre no coincide con tu negocio.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF143122),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.storefront_rounded,
                color: Color(0xFFC6F24E), size: 60),
            const SizedBox(height: 16),
            const Text(
              'TenderApp',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa tu PIN',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 40),
            // Indicadores de dígitos con animación shake
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final offset =
                    _shakeController.isAnimating ? 10.0 * (0.5 - (_shakeAnimation.value % 1).abs()) : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entered.length
                          ? const Color(0xFFC6F24E)
                          : Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: _errorMsg.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _errorMsg,
                style: const TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Column(
                children: [
                  _buildNumRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildNumRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildNumRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEmptyKey(),
                      _buildDigitKey('0'),
                      _buildBackspaceKey(),
                    ],
                  ),
                ],
              ),
            ),
            if (_failedAttempts >= 3)
              TextButton(
                onPressed: _forgotPin,
                child: const Text(
                  '¿Olvidaste tu PIN?',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildDigitKey).toList(),
    );
  }

  Widget _buildDigitKey(String digit) {
    return InkWell(
      onTap: () => _onDigit(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
        ),
        child: Text(
          digit,
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined,
            color: Colors.white60, size: 26),
      ),
    );
  }

  Widget _buildEmptyKey() {
    return const SizedBox(width: 72, height: 72);
  }
}

// Pantalla para configurar/cambiar/eliminar el PIN
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  // Pasos: 'current' | 'new' | 'confirm'
  String _step = 'new';
  String _entered = '';
  String _firstPin = '';
  String _errorMsg = '';
  String _subtitle = 'Elige un PIN de 4 dígitos';

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.hasPinEnabled) {
      _step = 'current';
      _subtitle = 'Ingresa tu PIN actual';
    }
  }

  void _onDigit(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _errorMsg = '';
    });
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 100), _advance);
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _advance() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (_step == 'current') {
      if (!settings.verifyPin(_entered)) {
        setState(() {
          _entered = '';
          _errorMsg = 'PIN incorrecto';
        });
        return;
      }
      setState(() {
        _step = 'new';
        _entered = '';
        _subtitle = 'Elige un nuevo PIN de 4 dígitos';
      });
    } else if (_step == 'new') {
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _step = 'confirm';
        _subtitle = 'Confirma el nuevo PIN';
      });
    } else if (_step == 'confirm') {
      if (_entered != _firstPin) {
        setState(() {
          _entered = '';
          _step = 'new';
          _firstPin = '';
          _errorMsg = 'Los PINs no coinciden';
          _subtitle = 'Elige un PIN de 4 dígitos';
        });
        return;
      }
      settings.setPin(_entered).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN configurado correctamente')),
          );
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF143122),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title:
            const Text('Configurar PIN', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              _subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _entered.length
                        ? const Color(0xFFC6F24E)
                        : Colors.white24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: _errorMsg.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(_errorMsg,
                  style: const TextStyle(
                      color: Color(0xFFFF3B30), fontSize: 14)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 72),
                      _buildKey('0'),
                      InkWell(
                        onTap: _onBackspace,
                        borderRadius: BorderRadius.circular(40),
                        child: const SizedBox(
                          width: 72,
                          height: 72,
                          child: Icon(Icons.backspace_outlined,
                              color: Colors.white60, size: 26),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map(_buildKey).toList(),
      );

  Widget _buildKey(String digit) {
    return InkWell(
      onTap: () => _onDigit(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
        child: Text(digit,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
