# Auditoría técnica de ATBA Modern

Fecha: 19 de octubre de 2026. Base: `e3d76b57bc4dd67b89c6844ae5c9e2d5946d1af3`. Rama: `feat/atba-modern-overhaul`.

Este informe se guarda antes de la refactorización. Los estados iniciales de la tabla son **abierto**; las correcciones y su evidencia se registrarán sin sustituir los hallazgos originales. Confirmado significa demostrado por lectura del flujo; probable requiere reproducción; opcional es una mejora de producto. No se han probado una cuenta real ni un teléfono.

## Arquitectura y dependencias

La aplicación mezcla modelos con operaciones remotas mediante un singleton estático (`LibraryItem.apiService`), un servicio de compatibilidad de 1.379 líneas y el paquete tipado `torbox_api`. Provider sirve dependencias; `LibraryPageState` contiene contexto de UI, selección, persistencia y HTTP. La biblioteca crea su Provider al montar la pestaña; el shell sustituye pantallas y pierde su estado. Hay dos MaterialApp anidados y dos sistemas de tema. El descubrimiento Stremio/Cinemeta sigue acoplado al arranque aunque no es necesario para administrar TorBox.

La persistencia usa FlutterSecureStorage, Settings/SharedPreferences y dos cachés Drift. Los modelos generados están versionados. Flutter está fijado a 3.47.5 en CI; Dart requiere >=3.13.0. Se instaló el SDK 3.47.5 con Dart 3.13.4 durante la auditoría. El lockfile debe conservarse salvo cambios justificados.

## Registro de hallazgos

| ID | Clase / gravedad | Ubicación original aproximada | Explicación e impacto | Corrección propuesta | Prueba de aceptación | Estado inicial |
|---|---|---|---|---|---|---|
| A01 | Confirmado / crítica | torbox_service.dart:320–337 | Google se guarda en google_drive_token y se lee/elimina en google_drive_token_expiry. La conexión desaparece al reiniciar y el token real no se borra. | Unificar claves, guardar sesión y expiración en almacenamiento seguro, migrar sesiones antiguas. | Reinicializar servicio con el mismo almacén; borrar y comprobar aislamiento de TorBox. | abierto |
| A02 | Confirmado / alta | google_oauth.dart:31–105 | La UI considera conectado cualquier texto; ignora expiración y acepta callback sin comprobar HTTPS. | Estado explícito válido/expirado/desconocido; callback restringido; conservar credenciales ante fallos de red. | Expiración, callback de origen incorrecto y red temporal. | abierto |
| A03 | Confirmado / alta | google_oauth.dart:119–202 | Token manual visible y copia de OAuth al portapapeles. | Campo oculto sin sugerencias; eliminar copia de token. | Widget y revisión de ausencia de logs/clipboard de credenciales. | abierto |
| A04 | Confirmado / alta | torbox_service.dart:302; api_screen.dart:53; settings_page.dart:150 | Nueva API key sustituye la anterior antes de comprobarla; una validación fallida borra la sesión válida. | Validar con cliente aislado y persistir solo tras éxito; serializar cambios. | Credencial inválida, fallo de red y cambio válido. | abierto |
| A05 | Confirmado / alta | torbox_service.dart:306–312 | Cada guardado aplica un referido fijo sin consentimiento. | Eliminar la llamada automática. | Verificar solicitudes producidas por guardar clave. | abierto |
| A06 | Confirmado / alta | update_service.dart:48–86; jobs_update_service.dart:28–48 | Cualquier error cierra definitivamente el monitor; floor se aplica antes de multiplicar, colapsando el intervalo casi siempre a 5 s. | Polling cancelable sin solapamiento, backoff limitado y recuperación. | HTTP transitorio seguido de éxito; intervalos; cancelación. | abierto |
| A07 | Confirmado / alta | library_page_state.dart:41,310 | Suscripciones por int comparten espacio entre torrent/web/Usenet. | Identidad compuesta y sincronización central de listas. | Tres tipos con el mismo ID. | abierto |
| A08 | Confirmado / alta | library_item_cache_service.dart:16 | itemId UNIQUE reemplaza registros de tipos diferentes. | UNIQUE(itemType,itemId), migración transaccional sin borrar filas existentes. | Migración de v2, persistencia, upsert y eliminación por tipo. | abierto |
| A09 | Confirmado / alta | library_page_state.dart:90–122; torbox_service.dart:378 | Monitores se inician solo para elementos iniciales; web/Usenet nuevos o añadidos fuera no se descubren. La creación usa defaultValue:false. | Polling de listas completas por tipo y cola, deduplicado y con descubrimiento periódico. | Añadir desde otra sesión y comprobar progreso de los tres tipos. | abierto |
| A10 | Confirmado / alta | home_page.dart:249–294 | El shell sustituye páginas; la biblioteca pierde Provider, selección y monitores. | Shell con estado retenido y control de pestaña visible. | Navegar y regresar sin perder estado ni duplicar peticiones. | abierto |
| A11 | Confirmado / alta | downloadable_item_detail_screen.dart:18 | Detalles retienen la instancia inicial; reemplazar un elemento en biblioteca no actualiza el detalle. | Escuchar una fuente compartida por identidad. | Lista y detalles muestran la misma actualización. | abierto |
| A12 | Confirmado / alta | jobs_status_page.dart:148–188 | Cada recarga reasigna late final y crea suscripciones sin guardar/cancelar; acceso a índice -1 y setState después de dispose. | Un coordinador de jobs por página, cancelación y guards. | Recarga repetida, job desaparecido y dispose durante HTTP. | abierto |
| A13 | Confirmado / alta | servicios de polling y biblioteca | No se observa ciclo de vida; se consulta en segundo plano y no se fuerza recuperación al volver. | Pausar timers al ocultar/inactivar; refrescar en resumed. | Segundo plano, navegación y reanudación. | abierto |
| A14 | Confirmado / media | library_page_state.dart:463–680 | Selección compara solo ID y borra caché incluso si falla la eliminación remota. | Identidad compuesta y borrar únicamente resultados exitosos. | Operación parcial con mismo ID en tipos distintos. | abierto |
| A15 | Confirmado / alta | cache_dio_interceptor.dart:50–77 | handler.resolve entrega 4xx/5xx como respuestas satisfactorias, saltándose validación HTTP/reintentos de Dio. | Bypass de caché para solicitudes frescas; validar status antes de resolver. | 401/429/503 y cabeceras Retry-After. | abierto |
| A16 | Confirmado / media | cache_http_client.dart:65–145 | jobs nunca cache incluye plural pero no /job/id; polling puede leer cache. GET no tiene timeout; fallback puede esconder errores. | Sacar lecturas volátiles del adaptador y usar Dio con timeout/retry. | Job cambia; red se interrumpe; no reutilizar estado obsoleto. | abierto |
| A17 | Confirmado / alta | retry_interceptor.dart:40–73 | Se reintentan POST automáticamente ante timeout/5xx: una creación aceptada puede duplicarse. | Reintentar automáticamente solo lecturas idempotentes; cancelación durante backoff; Retry-After con fecha. | POST no repetido; GET recupera; cancelación. | abierto |
| A18 | Probable / media | modelos legacy fromJson | Casts obligatorios y null de modelos tipados pueden romper bibliotecas con datos incompletos o estados nuevos. | Normalizar campos opcionales según contrato y probar fixtures. | Respuestas mínimas, vacías y estado desconocido. | abierto |
| A19 | Confirmado / media | main.dart:145; home_page.dart:70 | MaterialApp anidados y temas divergentes; indexOf de tema desconocido puede dar -1. | Un solo MaterialApp, tema M3 con fallback y tipografía Inter. | Tema desconocido, oscuro/claro/sistema y navegación. | abierto |
| A20 | Confirmado / alta | android/app/build.gradle:39 | storeFile file(null) en configuración release impide incluso compilar debug sin secretos. | Configurar firma release solo cuando está completa; APK debug instalable sin secretos. | Compilar ARM64 sin key.properties. | abierto |
| A21 | Confirmado / alta | .github/workflows/debug.yml | CI necesita keystore para debug; no tiene formato ni análisis ni pruebas raíz; no valida APK ARM64 con nombre estable. | Workflow por etapas, manual/push/PR, pruebas de paquetes, artifacts y timeout. | Ejecutar workflow y comprobar artifact. | abierto |
| A22 | Confirmado / media | build-release.yml | Publica releases de tags automáticamente; firma/cambios de versión no tienen barreras de validación compartidas. | Release manual con firma obligatoria y validación; sin publicación oficial automática. | Sin secretos falla claramente antes de distribuir. | abierto |
| A23 | Confirmado / media | cache/native.dart:24 | sqlite3.tempDirectory apunta a un archivo .sqlite, no a un directorio existente. | Usar directorio temporal de Android válido. | Abrir SQLite y ejecutar operaciones temporales. | abierto |
| A24 | Confirmado / media | home_page.dart:129–240 | Intents disparan creaciones directamente, exponen URL/rutas en avisos y no limitan duplicados; enlaces de texto compartidos son ignorados. | Bandeja de añadir con validación y envío explícito, admitir torrent/NZB/URLs. | Intents duplicados e inválidos, sin creación automática. | abierto |
| A25 | Confirmado / media | api_screen.dart:13; settings_page.dart:30 | Controladores se crean sin dispose o en build; doble submit no se bloquea. | Formularios Stateful con lifecycle y estado ocupado. | Doble toque y desmontaje durante validación. | abierto |
| A26 | Probable / media | library_page_state.dart:400–466 | Escribe caché en microtasks no esperadas y loguea excepciones completas. Posibles carreras y filtración de datos de URLs. | Transacciones await, conservar datos en error y diagnósticos redactados. | Fallo de caché/red y actualización concurrente. | abierto |
| A27 | Opcional / media | watch_page.dart, stremio* | Descubrimiento ajeno al objetivo de administración; dependencias compartidas con playback. | Retirar Watch del shell sin borrar playback ni módulos compartidos aún utilizados. | Abrir/previsualizar archivo sigue disponible. | abierto |
| A28 | Opcional / media | servicios RSS/user/notifications | Biblioteca API expone feeds, notificaciones, estadísticas, suscripciones/transacciones sin interfaz principal. | Pantallas sobre capacidades documentadas, sin inventar endpoints ni métricas. | Adaptadores HTTP y widgets con respuestas reales simuladas. | abierto |
| A29 | Probable / media | dependencias Git | flutter_settings_screens sin mantenimiento según pubspec; background_downloader usa rama que ya no anuncia ref aunque el commit fijado es descargable. | Evaluar actualización compatible y fijar commits verificables sin upgrade masivo. | Instalación frozen y compilación. | abierto |
| A30 | Opcional / baja | dependencias/cache | Varios cache stores y dos stacks HTTP se solapan; no hay revisión de advisories documentada. | Retirar solo dependencias sin imports; revisar pub outdated/advisories accesibles. | Resolución y pruebas; no afirmar ausencia de CVEs sin fuente. | abierto |

## API: inventario y límites de verificación

El paquete tipado incluye torrents, Usenet, webdl, cola, user, RSS, notificaciones, integraciones, streaming y endpoints generales. El adaptador legacy cubre principalmente los primeros y Google. Existen listados paginados por offset/limit; hay que distinguir una página de una biblioteca completa. Dio tiene timeouts y reintentos; el adaptador de caché puede eludirlos. No hay cancelación propagada a los métodos públicos ni limitador global; se prioriza un único coordinador de listas en vez de una petición por elemento.

Fuentes oficiales que deben contrastarse: https://api-docs.torbox.app y el enlace oficial de Postman. Las primeras peticiones devolvieron CONNECT 403; se guardó el requisito de red junto con api.github.com. Hasta acceder a una especificación oficial no se considerarán verificados parámetros nuevos. No se probó ningún endpoint privado con una cuenta real. La biblioteca existente y sus tests son evidencia de implementación, no prueba de compatibilidad oficial actual.

No se ha encontrado un refresh token de Google persistido ni un endpoint de renovación verificado. No se fabricará un refresh ni se reutilizará la API key de TorBox como token Google. Una credencial local sin expiración conocida no equivale a conexión verificada. La desconexión local no revoca automáticamente acceso en Google.

## Recursos y validación inicial

Linux x86_64, ~30 GB libres al comenzar, ~33 GiB RAM; Chromium y Java 21 instalados, Android SDK no instalado. Android ARM64 es objetivo; una compilación no sustituye pruebas físicas. Flutter 3.47.5 requiere SDK Android/Gradle coherentes con compileSdk 36 y AGP 9.0.1. iOS no se puede validar en esta máquina.

Git HTTPS de lectura funciona. GitHub API con gh devolvió Forbidden; no implica ausencia de permiso Git de escritura. Se probará publicación de rama sin force push al terminar. Actions/PR quedan condicionados al acceso real. Las pruebas de TorBox en vivo se omiten sin TORBOX_API_KEY; no se usarán credenciales ficticias ni operaciones destructivas.

Resultados ejecutados y estados finales se mantienen en TEST_REPORT.md y en la sección de resolución que se añadirá a este informe.


## Evidencia adicional previa al rediseño

Tras guardar el informe inicial se habilitó acceso: OpenAPI oficial consultado (87 rutas) y colección Postman oficial desde api-docs.torbox.app. Se conserva un extracto y SHA-256 en TORBOX_API_CONTRACT.json. Límite general documentado: 300/min por token; crear torrents no cacheados: 60/h. Los listados usan por defecto limit=1000: se implementará paginación explícita. El progreso de jobs está en rango 0–1, no 0–100. RSS requiere plan Pro y scan_interval se expresa en minutos. /integration/oauth/me y /oauth/{provider}/unregister existen; no se encontró contrato público de renovación local de Google. La verificación HTTP pública no demuestra autenticación ni ejecución en una cuenta.

Baseline ejecutado: 1.277 pruebas del parser y 64 de torbox_api pasan. El primer análisis falló por directorio HOME de solo lectura; se corrigió mediante ANALYZER_STATE_LOCATION_OVERRIDE, sin cambiar HOME. Segundo análisis: 90 diagnósticos heredados (sin errores de compilación, dos warnings). GitHub API ya responde y confirma acceso push/admin; se comprobará la operación de publicación al terminar.

## Resolución y evidencia al entregar

| Hallazgo | Estado | Evidencia / límite |
|---|---|---|
| A01 | Corregido | google_drive_session_test: registro seguro atómico, migración, restauración y borrado. Android físico pendiente. |
| A02–03 | Corregido dentro del contrato disponible | Callback HTTPS exacto, expiración, actualización al reanudar, campo protegido y sin copia de OAuth. No se inventa refresh. |
| A04–05 | Corregido | credentials_test: la anterior se conserva, solo GET de validación, sin referido automático. |
| A06–07 | Corregido | Scheduler compartido, intervalos explícitos, sin streams por ID numérico, backoff y cancelación. |
| A08 | Corregido | library_cache_test: migración v2→v3 con datos existentes; tres tipos con el mismo ID, upsert/borrado/persistencia. |
| A09–11 | Corregido | Snapshot compartido, paginación, descubrimiento, IndexedStack y widget lista/explorador sincronizados. |
| A12–13 | Corregido | Jobs con un solo poller, guards de mounted, sin late final reasignado; lifecycle probado en scheduler y controlador. |
| A14 | Corregido | Selección por identidad, eliminación local solo de éxitos, exclusión de acciones simultáneas y errores parciales visibles. |
| A15–16 | Corregido para el flujo actual | API tipada usa Dio directamente y la caché de biblioteca es explícita. Adaptador legado valida HTTP y excluye lecturas volátiles. |
| A17 | Corregido | retry_safety_test: POST no se repite; GET limitado; cancelación de sesión y Retry-After soportado. |
| A18 | Mitigado | Trabajo con nombre ausente aceptado; errores de conversión del adaptador se muestran de forma segura. Variaciones no documentadas requieren más fixtures reales. |
| A19 | Corregido | Un MaterialApp, tema M3 e Inter; fallback de modo desconocido probado. |
| A20–22 | Compilación Actions comprobada; firma ampliada en la puerta de artifacts | validate y android aprobaron en 39239270267. Firma debug independiente; workflow validación/APK; release y release-please solo manuales. Ninguna release publicada por esta tarea. |
| A23 | Corregido | Directorio temporal SQLite existente; pruebas de apertura, migración y reapertura. Android físico pendiente. |
| A24–25 | Corregido en el flujo nuevo | Intents requieren envío explícito; formulario común con dispose, campo protegido y estado ocupado. |
| A26 | Corregido en el flujo nuevo | Persistencia esperada/transaccional, errores sin dumps ni URLs firmadas; suscripción del reproductor liberada. |
| A27 | Completado | Revisión de imports antes de retirar el catálogo y formularios sustituidos. Reproductor y administración preservados. |
| A28 | Implementado parcialmente | Dashboard, notificaciones, RSS, ajustes y registros de cuenta. Alcance y proveedores pendientes en KNOWN_LIMITATIONS. |
| A29 | Mitigado | Revisiones Git fijadas a los commits existentes descargables. No se introduce upgrade mayor de Flutter ni de plugins sin necesidad. |
| A30 | Revisado con alcance explícito | Tres stores sin imports retirados. Pub: 203 versiones, seis advisories, ninguno afecta al lock actual. No equivale a certificar AAR/NDK/Git. |

El extracto oficial, la revisión de dependencias y los tests se conservan en el repositorio. El estado exacto de análisis, suites, GitHub Actions y artifacts se registra en TEST_REPORT.md; las pruebas de cuenta/dispositivo reales no se presentan como aprobadas.
