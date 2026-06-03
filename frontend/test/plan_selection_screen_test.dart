import 'package:MovieWind/screens/plan_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan selection presents free plans without payment copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlanSelectionScreen(
          userEmail: 'ana@example.com',
          userName: 'Ana',
          password: 'password123',
        ),
      ),
    );

    expect(find.text('Gratis'), findsWidgets);
    expect(find.textContaining('S/'), findsNothing);
    expect(find.textContaining('metodo de pago'), findsNothing);
    expect(find.textContaining('método de pago'), findsNothing);
    expect(find.text('Activar y continuar'), findsOneWidget);
  });
}
