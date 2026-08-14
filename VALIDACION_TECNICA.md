# Validación técnica inicial

Fecha: 14 de agosto de 2026.

## Entorno comprobado

- MacBook Pro con Apple M4 (`arm64`).
- macOS Tahoe 26.5.2, build 25F84.
- Solo están instaladas las Command Line Tools.
- Swift disponible: 5.3.2.
- Xcode completo no está instalado o no está seleccionado.

Conclusión: la inspección puede continuar, pero para crear, firmar y ejecutar la aplicación SwiftUI será necesario instalar Xcode completo.

## Navegadores instalados

| Navegador | Bundle identifier | Versión comprobada | Resultado inicial |
|---|---|---:|---|
| Arc | `company.thebrowser.Browser` | 1.159.0 | Sin diccionario AppleScript Chromium estándar; requiere prueba controlada con Accesibilidad o extensión. |
| Comet | `ai.perplexity.comet` | 151.0.7922.247 | Expone ventana, pestaña activa, título y URL mediante Apple Events. |
| Brave | `com.brave.Browser` | 150.1.92.139 | Expone ventana, pestaña activa, título y URL mediante Apple Events. |
| Safari | `com.apple.Safari` | 26.5.2 | Expone pestañas, título y URL mediante Apple Events. |

No se leyeron ni almacenaron títulos o URLs de pestañas reales durante esta inspección.

## Estrategia de captura

- Detectar primero la aplicación frontal mediante `NSWorkspace`.
- Comet y Brave: proveedor Chromium mediante Apple Events.
- Safari: proveedor Safari mediante Apple Events.
- Arc: intentar título mediante Accesibilidad y URL mediante una prueba controlada. Si Arc no expone la URL de forma fiable, usar una extensión mínima con comunicación nativa solo para ese navegador.
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

1. Arc puede no entregar la URL mediante Apple Events.
   - Mitigación: Accesibilidad para título y extensión mínima para URL si fuera necesaria.
2. Los permisos de Automatización son individuales por navegador y Mac.
   - Mitigación: asistente de primera ejecución y estado visible de cada permiso.
3. Una actualización de navegador puede modificar su interfaz de automatización.
   - Mitigación: proveedores separados, degradación a título de ventana y pruebas por navegador.
4. La API pertenece a la imagen oficial y podría evolucionar.
   - Mitigación: cliente aislado, validación de respuestas y errores claros sin acceso directo a PostgreSQL.

## Validaciones pendientes

- Instalar Xcode completo y seleccionar su toolchain.
- Probar cada navegador con una página controlada, después de conceder permisos.
- Crear un token de Timebase con permisos de lectura y escritura.
- Consultar proyectos reales mediante API.
- Crear y eliminar o revisar un único registro de prueba controlado.

