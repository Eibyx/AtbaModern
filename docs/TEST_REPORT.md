# Informe de pruebas

Entorno: Linux x86_64, Flutter 3.47.5, Dart 3.13.4. Se usa el SDK fijado por el repositorio. La biblioteca SQLite del sistema se expuso mediante un enlace local a libsqlite3.so; no se cambió HOME, TLS, firmas ni checksums. Analyzer usa un directorio de estado escribible fuera del checkout.

## Resultados locales

| Comprobación | Resultado |
|---|---|
| Instalación de dependencias con lockfile | Ejecutada; revisiones Git fijadas y hashes de Pub preservados |
| Generación raíz / paquete torbox_api | Ejecutada; versión de esquema Drift 3 generada |
| Formato de todo el repositorio | Ejecutado; CI exige cero diferencias |
| Análisis estático | Sin diagnósticos en el verificador completo |
| Suite raíz | 27 pruebas pasan en la última ejecución completa, incluidas pruebas de widgets |
| Parser interno | 1.277 pruebas pasan; se incluye en el verificador final |
| API tipada | 64 pruebas pasan con los modelos actualizados y el PUT parcial |
| Web release | Compilación y dry-run Wasm correctos |
| Chromium, pantalla de acceso | Arranque real, título ATBA Modern, vista Flutter y cero pageerrors; captura en screenshots/onboarding.png |
| Cuenta TorBox / Google real | No ejecutado: no se usan claves ni operaciones reales para validar mocks |
| Teléfono Android | No ejecutado |

El verificador completo terminó correctamente: formato sin diferencias, análisis sin diagnósticos, 27 pruebas raíz, 64 pruebas API y 1.277 pruebas del parser. GitHub Actions y su artifact se registran más abajo al comprobar su ejecución. Un fallo inicial de un finder del formulario de ajustes se corrigió desplazando la lista hasta construir el botón; se mantuvo la aserción de que el PUT contiene únicamente el campo cambiado.

## Cobertura de regresiones

- Sesión Google: guardado, nuevas instancias, migración del token antiguo, borrado, expiración, origen de callback y error temporal que conserva ambas credenciales.
- Cuenta: clave rechazada/válida/vacía, conservación de la anterior y ausencia de referido/mutaciones extra.
- Scheduler: seis segundos con actividad, intervalo inactivo, backoff/recuperación, pausa/reanudación, cancelación y deduplicación de solicitudes simultáneas.
- Biblioteca: torrent/Usenet/web con igual ID, progreso y finalización, error HTTP con conservación de datos, descarte de respuestas tras dispose y registro de estado activo liberado.
- SQLite: colisiones entre tipos, upsert, borrado por tipo, migración v2→v3 con filas conservadas y persistencia tras cerrar/reabrir.
- Jobs: recuperación de una respuesta fallida, progreso real 0–1, finalización que cierra el monitor y cancelación que detiene consultas.
- HTTP: GET reintenta un número limitado de veces; POST no se duplica tras 503.
- UI: cuatro pestañas con estado retenido, filtros, errores, progreso simultáneo de lista/explorador, fallback de tema y edición remota que conserva campos no modificados.
- Entradas: detección magnet/NZB/torrent/web, normalización de infohash y rechazo de esquemas/credenciales incrustadas.
- Avisos locales: ni snapshot inicial ni repetición de un finalizado genera eventos falsos; una transición real produce un aviso.

## Revisión de dependencias

Metadatos oficiales de Pub revisados para 203 versiones alojadas. Cuatro paquetes publican seis advisories en la información consultada (archive, dio, http y shared_preferences_android); ninguna de las versiones fijadas cae en sus rangos afectados. Evidencia: DEPENDENCY_REVIEW.json. Esto no equivale a una certificación de todas las dependencias nativas/Git ni de amenazas desconocidas.

## Aceptación manual

Los escenarios A–E y las comprobaciones pendientes se especifican en KNOWN_LIMITATIONS.md. Las pruebas físicas de muerte de proceso/reinicio, autorización Google, transferencias reales, descarga local/permisos y rendimiento en una biblioteca grande siguen siendo necesarias.
