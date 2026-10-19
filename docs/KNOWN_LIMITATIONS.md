# Limitaciones y comprobación manual

## Validación que requiere cuenta o dispositivo

No se usó una API key real ni se realizaron operaciones sobre una cuenta real. Las respuestas de pruebas son mocks identificados como tales. Los siguientes escenarios no se consideran aprobados por una compilación ni por pruebas de servicios:

| Escenario | Evidencia automatizada | Pendiente manual |
|---|---|---|
| A · Persistencia Google Drive | Guardado seguro, migración, nueva instancia, caducidad y aislamiento de la API key | Autorizar en Android, cerrar/forzar parada, matar proceso y reiniciar teléfono; confirmar que la credencial aún válida permite transferir |
| B · Progreso automático | Snapshot común de torrent/Usenet/web, scheduler, errores transitorios, fin y lifecycle; widget de lista/detalle | Transferencias reales de los tres tipos, cambio de pestañas y altas desde la web de TorBox |
| C · Envío a Drive | Endpoint oficial, separación de credenciales y monitor de job con recuperación/finalización/cancelación | Envío real, permisos/carpetas, progreso remoto, errores del proveedor y caducidad OAuth |
| D · Estabilidad | IDs coincidentes, persistencia SQLite, migración v2→v3, sin consultas de refresco duplicadas y filtros retenidos | Biblioteca grande y consumo de batería/memoria en distintos teléfonos y redes |
| E · APK | Workflows con checks y verificación ZIP/checksum | Instalación y funcionamiento físico; consultar TEST_REPORT para resultado de Actions |

## OAuth y autenticación

- No se encontró contrato de renovación local automática de Google. No se inventa un refresh token ni se reutiliza la API key TorBox. La sesión persiste solo durante la validez real del acceso.
- Google puede bloquear OAuth en WebView. Existe autorización desde el navegador con introducción manual protegida de token/URL de éxito; no hay un callback Android propio porque no se ha verificado soporte de redirect_uri personalizado de TorBox.
- Una credencial guardada o una expiración futura no prueban autorización actual ante Google. La UI lo indica; la transferencia puede descubrir una revocación anterior al vencimiento. Un fallo temporal no borra credenciales.
- La eliminación local no equivale a revocar la integración en el proveedor.
- El identificador Android propio crea almacenamiento independiente respecto al ATBA original. No se migran credenciales entre aplicaciones distintas.

## Alcance de funciones

- Se administra Google Drive y los jobs documentados. Dropbox, OneDrive, GoFile y otros proveedores no se presentan como conectados ni con una implementación de UI completa.
- Las preferencias de cuenta expuestas son un subconjunto: notificaciones, ZIP, siembra, nombre en enlaces, CDN y carpeta de Google. No se añaden compras, borrado de cuenta, Telegram, webhooks ni configuración arbitraria de todas las integraciones.
- Las notificaciones TorBox no devuelven un ID estructurado de la transferencia en el modelo oficial consultado; no se inventa un enlace a un elemento a partir del ID de la notificación. No hay operación de marcar como leído documentada en este cliente.
- Los avisos locales se generan al observar cambios en primer plano, con permiso optativo de Android. No hay FCM, worker persistente ni promesa de notificación instantánea con la app cerrada. La notificación no tiene aún navegación directa al elemento.
- El progreso al dispositivo lo gestiona background_downloader y su notificación nativa; no se ha añadido un historial local completo de descargas en la navegación principal.
- Webdl solo expone eliminación en el adaptador existente; no se muestran pausa/reanudación no contrastadas. La pausa múltiple se ofrece para Usenet. No se simulan movimientos ni renombrado de archivos remotos.
- La disponibilidad de caché se consulta para magnets; no se calcula un hash NZB/torrent inventado. Los límites de 20 enlaces y archivos de 10 MiB protegen memoria y duplicados accidentales.
- RSS es Pro, con mínimo oficial de 10 minutos. El estado de duplicados solo es editable si está disponible; una respuesta incompleta o un tipo desconocido requiere revisión antes de guardar, no debe reinterpretarse como un valor por defecto.
- Los métodos privados de búsqueda del adaptador legacy no se amplían ni se incluyen en la navegación. El catálogo y los proveedores Stremio se retiraron después de revisar imports; el reproductor de archivos permanece.

## Compilación y mantenimiento

- Debug signing es para pruebas y puede cambiar entre runners; no proporciona continuidad de actualización garantizada ni identidad de producción.
- Las plataformas Apple requieren herramientas de Apple; no se validaron. El arranque web se comprueba sin anunciar compatibilidad completa de plugins nativos.
- Los generadores pueden advertir que su versión de analyzer es anterior al lenguaje del SDK. La generación debe pasar junto con análisis y pruebas; no se ignoran errores ni se cambian checksums para forzarla.
- La revisión de dependencias usa avisos publicados por pub.dev y versiones fijadas; no certifica ausencia de vulnerabilidades desconocidas ni cubre completamente AAR, NDK, bibliotecas nativas o dependencias Git. OSV directo estuvo bloqueado en esta máquina; se utilizó la fuente oficial de advisories de Pub.
- La migración v2→v3 conserva filas, IDs y timestamps. El antiguo esquema anterior a v2 se conserva para recuperación en lugar de borrar su tabla; la biblioteca actual se vuelve a cargar desde TorBox. No puede reconstruir entradas que la antigua restricción UNIQUE ya había sobrescrito.

- El índice y el archivo binario de Flutter 3.47.5 consultados devolvieron 404; su tag oficial y los artefactos de su engine sí están disponibles. CI utiliza tool/setup_flutter.sh, que fija y verifica el commit oficial antes de ejecutar el bootstrap original de Flutter. No sustituye checksums ni desactiva TLS.
