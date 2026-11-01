CERCANO ORIENTE - ARCHIVOS ACTUALIZADOS
=======================================

Este paquete contiene los archivos actualizados de seguridad, backups, auditoría,
bloqueo automático configurable, limpieza temporal, versionado documental,
identidad institucional y firma PAdES.

INTEGRACIÓN SOBRE UNA COPIA LOCAL
---------------------------------
1. Haz una copia de seguridad de tu proyecto local.
2. Descomprime este ZIP en la carpeta raíz del proyecto Flutter.
3. Acepta la sustitución de archivos manteniendo las rutas incluidas.
4. Ejecuta:

   flutter pub get
   flutter analyze
   flutter test

5. Revisa los cambios:

   git status
   git diff

6. Crea el commit:

   git add lib pubspec.yaml
   git commit -m "Add security, backup, signing and configurable session lock"

ARCHIVOS INCLUIDOS
------------------
lib/db/orientation_repository.dart
lib/db/orientation_schema.dart
lib/models/orientation_models.dart
lib/models/signing_models.dart
lib/services/backup_service.dart
lib/services/pades_signing_service.dart
lib/services/report_export_service.dart
lib/services/temporary_cleanup_service.dart
lib/ui/dashboard_page.dart
lib/ui/login_page.dart
lib/ui/settings_page.dart
lib/ui/student_case_page.dart
pubspec.yaml

NOTA
----
No se incluye la base de datos de trabajo ni certificados .p12/.pfx.
Ejecuta flutter analyze y flutter test antes del commit definitivo.
