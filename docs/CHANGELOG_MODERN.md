# Cambios de ATBA Modern

## Desarrollo · 19 de octubre de 2026

### Correcciones

- Persistencia OAuth Google en un registro seguro atómico, migración de claves, fecha de caducidad y borrado independiente de TorBox.
- Validación aislada de nueva API key antes de sustituirla; eliminación del referido automático y de la copia de OAuth al portapapeles.
- Sustitución del intervalo con floor incorrecto y streams que terminaban ante un error por polling adaptativo, cancelable y sin ciclos solapados.
- Un snapshot central para lista, dashboard y detalles; descubrimiento de nuevos elementos, paginación y pausa/reanudación por lifecycle.
- Caché con identidad tipo + ID y migración SQLite v3 conservando registros de v2; corrección del directorio temporal de SQLite.
- Jobs sin suscripciones huérfanas, índices -1 ni reasignación de late final al refrescar.
- POST sin reintento automático; GET con backoff y Retry-After. Cancelación de cliente al cambiar de sesión y excepciones sin query strings de credenciales.
- Fallos de arranque con recuperación explícita y fallos de operaciones masivas visibles.

### Interfaz y administración

- Un MaterialApp M3, Inter, temas claro/oscuro/sistema y color dinámico.
- Navegación retenida Inicio/Descargas/Automatizaciones/Cuenta, responsive con NavigationRail.
- Dashboard de cuenta/estadísticas, biblioteca unificada y explorador de archivos con progreso compartido.
- Añadir lotes y archivos, revisión de intents Android y comprobación de caché de magnets.
- Notificaciones TorBox, RSS, consultas de suscripción/transacciones y ajustes parciales de cuenta.
- Avisos locales Android opcionales para cambios observados en primer plano; trabajos de integración separados de las descargas locales.
- Retirada del subgrafo de catálogo Stremio tras revisar imports; se conserva reproducción y apertura de archivos.

### Dependencias, pruebas y distribución

- Dependencias Git existentes fijadas por commit; retirada de tres stores HTTP sin uso y fuente Cupertino incluida para iconos heredados.
- Pruebas de sesiones, credenciales, scheduler, migraciones/persistencia, actualización común, retries, jobs, enlaces, notificaciones y widgets.
- Identificador Android propio; debug sin secretos; release firmada manual mediante secrets del usuario, sin publicación automática.
- Workflow manual/push/PR con generación, formato, análisis, pruebas y artifacts ARM64/universal opcional, comprobación ZIP y SHA-256.

Las verificaciones y limitaciones reales se documentan en TEST_REPORT.md y KNOWN_LIMITATIONS.md; no se declara aceptación física de Android ni de OAuth real sin ejecutarla.
