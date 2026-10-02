import 'package:flutter_test/flutter_test.dart';

import 'package:cercano_oriente/main.dart';

void main() {
  testWidgets('la aplicación muestra la pantalla de acceso', (tester) async {
    await tester.pumpWidget(const CercanoOrienteApp());
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
