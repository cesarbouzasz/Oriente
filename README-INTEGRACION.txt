CORRECCIÓN DECISIVA: MAIN DART USABA LOGIN ANTIGUO
=================================================

La causa era que lib/main.dart contenía otra clase LoginPage antigua y NO
importaba/mostraba lib/ui/login_page.dart. Por eso los ZIP anteriores podían
contener la pantalla nueva, pero Windows seguía compilando la pantalla vieja.

Este paquete incluye ahora OBLIGATORIAMENTE:
  lib/main.dart
  lib/ui/login_page.dart
  lib/services/file_selection_service.dart
  pubspec.yaml
  assets/images/*
  .github/workflows/build-platforms.yml

Extrae el contenido directamente sobre la raíz de Oriente y reemplaza archivos.
En GitHub Desktop deben aparecer cambios en lib/main.dart y lib/ui/login_page.dart.
Haz commit y push.

Antes de compilar comprueba en GitHub que lib/main.dart contiene:
  import 'ui/login_page.dart';
  home: const LoginPage(),

Y que NO contiene una segunda definición:
  class LoginPage extends StatefulWidget

En la nueva ejecución, descarga el artifact Windows de esa ejecución, no uno anterior.
