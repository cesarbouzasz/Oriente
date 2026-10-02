# Cercano Oriente — Fase 1 MVP

Base Flutter para Windows, macOS y Android. El objetivo es trabajar **sin backend y sin nube**, con una base de datos SQLCipher portable.

## Estado del esqueleto

Incluye:

- Pantalla de portada/login con contraseña máster.
- Selector de archivo `.db` mediante picker nativo.
- Servicio de backup que copia el archivo cifrado sin conocer ni almacenar la contraseña.
- Restauración preparada mediante copia temporal.
- Comprobación obligatoria de `PRAGMA cipher_version`; si el binario no es SQLCipher, la app se detiene.
- Separación de UI, selección de archivos, base de datos y backups.

## Arranque

```bash
flutter pub get
flutter run -d windows
# o
flutter run -d macos
```

Este sandbox no contiene el SDK Flutter, por lo que la compilación debe ejecutarse en una máquina con Flutter instalado.

## Integración nativa SQLCipher implementada

El proyecto usa el mecanismo oficial de **native assets/hooks de `sqlite3 3.x`**. La sección `hooks.user_defines` de `pubspec.yaml` selecciona `source: sqlcipher`, que descarga el binario SQLCipher publicado para:

- Android: armv7a, arm64-v8a, x86 y x86_64.
- macOS: Intel y Apple Silicon.
- Windows: x64 (y el target soportado por el binario publicado).

```yaml
hooks:
  user_defines:
    sqlite3:
      source:
        android: sqlcipher
        macos: sqlcipher
        windows: sqlcipher
        default: sqlcipher
```

El adaptador Dart ejecuta `PRAGMA key`, verifica `PRAGMA cipher_version` y comprueba el page size de SQLCipher antes de crear o modificar tablas. SQLCipher 4 utiliza AES-256-CBC con HMAC-SHA512 por defecto.

No se usa `sqflite` normal ni se cifran únicamente columnas. Si el hook no consigue cargar el binario SQLCipher, la aplicación se detiene y no abre la base de datos.

### Compilación y verificación

En una máquina con Flutter estable y las toolchains de cada plataforma:

```bash
flutter clean
flutter pub get
flutter run -d windows
flutter run -d macos
flutter build apk --release
```

La primera compilación necesita descargar los artefactos nativos publicados por `sqlite3`; debe ejecutarse con acceso a Internet. Para una build reproducible en CI se debe conservar `pubspec.lock`, fijar la versión de `sqlite3` y verificar los hashes/SBOM de los artefactos nativos descargados.

La prueba mínima de aceptación es abrir una base con contraseña conocida y comprobar:

```sql
PRAGMA cipher_version;
PRAGMA cipher_page_size;
```

Nunca se debe reemplazar estas comprobaciones por una bandera de configuración.

## Pendrive y Android

La Fase 1 deja el origen de datos abstraído. En escritorio, `file_picker` devuelve la ruta local o del pendrive. Para Android, la implementación final debe añadir un adaptador SAF/USB OTG que:

1. Obtenga un URI persistente con el permiso de lectura/escritura.
2. Copie el `.db` cifrado al almacenamiento privado de la app.
3. Abra y modifique únicamente esa copia local.
4. Sincronice de forma atómica al guardar/cerrar: escribir temporal, `fsync`/rename cuando el proveedor lo permita y conservar el original hasta verificar tamaño/hash.
5. Detecte la desconexión y bloquee la sincronización destructiva.

No se debe tratar un URI SAF como una ruta POSIX. El adapter Android será una fase específica.

## Seguridad y RGPD — decisiones iniciales

- La contraseña máster no se guarda en preferencias, logs ni backups.
- No hay telemetría, analítica ni red en el MVP.
- Usar contraseñas de mínimo 12 caracteres; recomendar frase de paso.
- Evitar logs con rutas completas, nombres de alumnos o contenido clínico.
- El cierre de sesión debe cerrar la conexión y limpiar referencias en memoria; para protección fuerte contra malware local se evaluará un proceso/isolate nativo y políticas de memoria.
- Los backups heredan el cifrado de SQLCipher, pero necesitan control de acceso del sistema de archivos y política de retención.
- Antes de producción: DPIA/EIPD, registro de actividades, base jurídica, minimización, retención/borrado, gestión de derechos y procedimiento de pérdida de dispositivo.

## Estructura

```text
lib/
  main.dart
  core/app_config.dart
  db/encrypted_database.dart
  services/file_selection_service.dart
  services/backup_service.dart
assets/images/portada_cercano_oriente.jfif
```

## Próximos pasos

1. Añadir build reproducible de SQLCipher native assets y pruebas que fallen si `cipher_version` está vacío.
2. Crear repositorios/modelos de Fase 2 con consultas parametrizadas y migraciones.
3. Añadir restauración con confirmación, validación SQLCipher y rollback.
4. Implementar SAF/USB OTG y sincronización atómica para Android.
5. Firmar instaladores y APK, activar hardening, pruebas de desconexión y auditoría RGPD.
