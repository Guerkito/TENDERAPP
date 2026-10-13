import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenderapp/main.dart';
import 'package:tenderapp/screens/login_screen.dart';

void main() {
  testWidgets('sin sesión iniciada, la app abre en la pantalla de login',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('ENTRAR A MI TIENDA'), findsOneWidget);
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
  }

  /// La tarjeta puede quedar bajo el borde del viewport de prueba: desplázala.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('pide correo y contraseña antes de intentar entrar',
      (tester) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text('ENTRAR A MI TIENDA'));

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  testWidgets('valida correo, mínimo de contraseña y confirmación al crear cuenta',
      (tester) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text('Crear cuenta'));
    expect(find.text('CREAR MI CUENTA'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'correo-malo');
    await tester.enterText(fields.at(1), '123');
    await tester.enterText(fields.at(2), '456');
    await tapVisible(tester, find.text('CREAR MI CUENTA'));

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(
        find.text('La contraseña debe tener al menos 6 caracteres'),
        findsOneWidget);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('ofrece recuperar la contraseña desde la pantalla de ingreso',
      (tester) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text('¿Olvidaste tu contraseña?'));

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('ENVIAR ENLACE'), findsOneWidget);
  });

  testWidgets('las contraseñas coincidentes pasan la validación local',
      (tester) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text('Crear cuenta'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'maria@correo.com');
    await tester.enterText(fields.at(1), 'secreto123');
    await tester.enterText(fields.at(2), 'secreto123');

    // Valida el formulario sin enviar (enviar haría una llamada de red real).
    final valid = tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();

    expect(valid, isTrue);
    expect(find.text('Las contraseñas no coinciden'), findsNothing);
    expect(find.text('Escribe un correo válido'), findsNothing);
    expect(find.text('La contraseña debe tener al menos 6 caracteres'),
        findsNothing);
  });
}
