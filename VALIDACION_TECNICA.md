# Validación técnica inicial

Fecha: 14 de agosto de 2026.

## Entorno comprobado

- MacBook Pro con Apple M4 (`arm64`).
- macOS Tahoe 26.5.2, build 25F84.
- Xcode 26.6 instalado, con licencia aceptada y configuración inicial completada.
- Swift disponible: 6.3.3.

Conclusión: el entorno está preparado para crear y compilar el prototipo nativo.

## Navegadores instalados

| Navegador | Bundle identifier | Versión comprobada | Resultado inicial |
|---|---|---:|---|
| Arc | `company.thebrowser.Browser` | 1.159.0 | Validado: aunque no publica diccionario propio, acepta el protocolo Apple Events de Chromium y devuelve título y URL. |
| Comet | `ai.perplexity.comet` | 151.0.7922.247 | Validado: `front window` mediante Apple Events devuelve correctamente título y URL; su título AX puede ser personalizado y no debe usarse para emparejar. |
| Brave | `com.brave.Browser` | 150.1.92.139 | Validado con varias ventanas: Accesibilidad identifica la enfocada y Apple Events devuelve título y URL. |
| Safari | `com.apple.Safari` | 26.5.2 | Validado: la pestaña actual de la ventana frontal devuelve título y URL mediante Apple Events. |

No se leyeron ni almacenaron títulos o URLs de pestañas reales durante esta inspección.

## Estrategia de captura

- Detectar primero la aplicación frontal mediante `NSWorkspace`.
- Comet y Brave: proveedor Chromium mediante Apple Events.
- Comet puede asignar un nombre propio a la ventana que no contiene el título de la pestaña; cuando Comet sea la aplicación frontal se consultará directamente su pestaña activa mediante Apple Events.
- En Brave, `front window` de Apple Events no siempre coincide con la ventana visualmente enfocada. La implementación debe obtener el título de la ventana frontal mediante Accesibilidad y buscar después la ventana/pestaña correspondiente mediante Apple Events.
- Safari: proveedor Safari mediante Apple Events.
- Arc: utilizar los códigos Apple Events del proveedor Chromium dirigidos a su bundle identifier. La prueba controlada confirmó título y URL sin extensión.
- Mantener un protocolo común `BrowserTabProvider` para que cada navegador pueda cambiar de implementación sin afectar el resto de la aplicación.

## API instalada de Timebase

Servidor validado: `https://time.22mw.online`.

### Autenticación

- Cabecera: `Authorization: Bearer <token>`.
- Tokens creados por Timebase con permisos `read` y/o `write`.
- Respuestas esperadas: `401` sin token, `403` sin el permiso necesario.
- El token se guardará exclusivamente en el Llavero de macOS.

### Proyectos

- `GET /api/raycast/projects`
- Requiere permiso `read`.
- Devuelve clientes activos y sus proyectos activos, incluyendo identificadores, nombres y tarifa.

### Crear un registro de tiempo

- `POST /api/raycast/time-entries`
- Requiere permiso `write`.
- Cuerpo JSON:

```json
{
  "projectId": "identificador",
  "startTime": "fecha ISO 8601",
  "endTime": "fecha ISO 8601",
  "description": "texto opcional"
}
```

- Campos opcionales adicionales: `hourlyRateCents` e `invoiced`.
- Valida que el fin sea posterior al inicio y que el proyecto exista.
- Devuelve `201` y el registro creado.

### Temporizadores

- `POST /api/raycast/timers/start`: proyecto y descripción.
- `GET /api/raycast/timers/active`: temporizador activo.
- `GET /api/raycast/timers/recent`: temporizadores recientes.
- `POST /api/raycast/timers/[id]/stop`: detener un temporizador.

El MVP utilizará inicialmente la creación de registros cerrados. Los temporizadores en tiempo real podrán añadirse después sin cambiar la arquitectura.

## Riesgos y mitigaciones

1. Arc no publica un diccionario AppleScript propio aunque acepte los eventos Chromium.
   - Mitigación: encapsular los códigos de eventos en su proveedor y conservar una alternativa futura mediante extensión si Arc cambia este comportamiento.
2. Los permisos de Automatización son individuales por navegador y Mac.
   - Mitigación: asistente de primera ejecución y estado visible de cada permiso.
3. Una actualización de navegador puede modificar su interfaz de automatización.
   - Mitigación: proveedores separados, degradación a título de ventana y pruebas por navegador.
4. La API pertenece a la imagen oficial y podría evolucionar.
   - Mitigación: cliente aislado, validación de respuestas y errores claros sin acceso directo a PostgreSQL.

## Validaciones completadas

- Brave: prueba controlada completada correctamente con `http://example.com/` y varias ventanas abiertas.
- Comet: prueba controlada completada correctamente con `http://example.com/`.
- Safari: prueba controlada completada correctamente con `http://example.com/`.
- Arc: prueba controlada completada correctamente con `http://example.com/` usando términos Chromium.
- Token `Timebase macOS` creado con permisos de lectura y escritura y almacenado en el Llavero de macOS.
- Lectura autenticada de proyectos validada contra producción con respuesta HTTP 200, sin mostrar el token ni descargar datos en la prueba.

## Validación pendiente

- Crear y eliminar o revisar un único registro de prueba controlado.
