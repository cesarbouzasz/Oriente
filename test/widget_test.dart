import 'package:flutter_test/flutter_test.dart';

import 'package:cercano_oriente/main.dart';

void main() {
  testWidgets('muestra la pantalla inicial de Cercano Oriente', (tester) async {
    await tester.pumpWidget(const CercanoOrienteApp());

    expect(find.text('Cercano Oriente'), findsOneWidget);
    expect(find.text('Programa de orientación · almacenamiento local'), findsOneWidget);
  });
}
