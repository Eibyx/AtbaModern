# Plan de implementación

Auditoría base guardada antes de refactorizar; ver AUDIT_REPORT.md. Trabajo sobre feat/atba-modern-overhaul con commits funcionales pequeños.

1. **P0 · Sesiones y seguridad** (A01–05, A17, A25): almacén inyectable, sesión Google segura con expiración/migración, validación aislada de nueva API key, quitar referido y copia de tokens, restringir OAuth. Pruebas de reinicio, fallos transitorios y no sustitución de claves.
2. **P0 · Progreso y persistencia** (A06–16, A23, A26): scheduler sin solapamiento/cancelable; polling de listas y jobs, lifecycle, identidad por tipo, migración SQLite v3 y fuente compartida con detalles. Pruebas con reloj simulado y DB real en memoria/archivo.
3. **Puerta de estabilidad**: ejecutar suites de paquetes y regresiones, analizar; corregir errores de compilación y documentar avisos heredados. No comenzar cambios visuales importantes antes de esta puerta.
4. **P1 · Shell y diseño** (A10, A19, A27): un MaterialApp M3, Inter, claro/oscuro/sistema y color dinámico; Inicio/Descargas/Automatizaciones/Cuenta con estado retenido; preservar apertura de archivos.
5. **P1 · Administración** (A24, A28): dashboard con datos oficiales; biblioteca unificada eficiente con filtros, selección, orden, búsqueda, progreso; añadir contenido validado; explorador con búsqueda/selección y enlaces; notificaciones, RSS y configuración de cuenta solo con contrato comprobado.
6. **P1 · Integraciones**: Google primero; estado local honesto, envío explícito, jobs con progreso y errores. No anunciar proveedores, refresh o cancelación sin contrato contrastado. Sin secretos reales, pruebas HTTP simuladas y escenarios manuales documentados.
7. **P1 · Android/CI** (A20–22): firma debug sin secretos, identificador propio tras revisar intent/OAuth, checks, APK ARM64 y universal como artifacts; ejecución manual y automática de rama; sin release oficial automática.
8. **P2 · Optimización/dependencias** (A18, A29–30): quitar imports/dependencias demostrablemente innecesarios, fijar revisiones Git, conservar caché al fallar red, limitar reconstrucciones y concurrencia; evitar cambios masivos de versiones.
9. **Entrega**: README, CHANGELOG_MODERN, TEST_REPORT y KNOWN_LIMITATIONS, evidencias de pruebas y APK; publicar rama sin force push y crear PR si funciona GitHub API.

## Alcance verificable

Las correcciones críticas y sus regresiones tienen prioridad. Las integraciones que dependan de especificaciones inaccesibles, credenciales o teléfono se registrarán como pendientes sin detener trabajo independiente. No habrá pantallas vacías ni botones de funciones simuladas. Se actualizarán los estados conforme se comprueben resultados; no se afirmará aceptación física A–E con pruebas unitarias solamente.


## Desacoplamiento del catálogo

Antes de retirar el flujo anterior se enumeraron sus imports entrantes. Watch, Details (catálogo), configuración Stremio/Torrentio, los cinco servicios de addons y los formularios/tablas antiguos solo se referenciaban entre sí y desde las pantallas sustituidas. No quedaban importadores externos en lib. Se retiró ese subgrafo, conservado en el historial Git, después de implementar sus equivalentes administrativos. Se mantienen el reproductor, apertura de archivos, modelos TorBox y ambos paquetes internos. Esto evita conservar pantallas duplicadas que escribían credenciales o gestionaban suscripciones con el flujo anterior.
