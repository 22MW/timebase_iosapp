# Timebase Activity para macOS — plan funcional y de desarrollo

## 1. Objetivo

Crear una aplicación nativa para macOS que registre la actividad del usuario en el ordenador, la organice en una línea temporal y permita convertir uno o varios periodos en registros de tiempo asociados a proyectos existentes de Timebase.

La aplicación será complementaria: no modificará el contenedor, la base de datos ni el código de Timebase. La comunicación se realizará mediante su API y un token del usuario, para que las actualizaciones oficiales no sobrescriban el trabajo.

## 2. Principios

- Privacidad local: la actividad se almacena en el Mac.
- Envío manual: nada llega a Timebase hasta que el usuario lo confirma.
- Sin vigilancia invasiva: no se registran teclas, contraseñas, formularios ni capturas de pantalla.
- Control visible: pausa rápida, exclusiones y borrado de datos.
- Sin duplicados: cada periodo enviado queda identificado localmente.
- Resistencia a actualizaciones: integración exclusivamente mediante API pública de Timebase.

## 3. Funcionalidades

### 3.1 Captura de actividad

- Detectar la aplicación que está en primer plano.
- Registrar título de la ventana activa cuando macOS lo permita.
- Crear un periodo nuevo cuando cambie la aplicación o el título relevante.
- Registrar inicio, fin y duración real.
- Detectar inactividad del teclado y ratón.
- Usar 5 minutos como umbral de inactividad predeterminado del MVP, configurable posteriormente.
- Conservar los periodos inactivos y mostrarlos en gris para revisión.
- No enviar periodos inactivos a Timebase salvo que el usuario los recupere expresamente.
- Pausar y reanudar el seguimiento desde la barra de menús.
- Permitir excluir aplicaciones, títulos o sitios sensibles.

### 3.2 Navegadores y pestañas

- Detectar el navegador activo.
- Registrar título y dominio/URL de la pestaña activa.
- Considerar cada cambio de pestaña activa como una actividad separada.
- No registrar todas las pestañas abiertas: solo la visible en ese momento.
- Agrupar de forma predeterminada pestañas consecutivas del mismo dominio en una sola actividad visible, aunque cambien el título o la URL.
- Conservar internamente cada segmento y cambio de pestaña para poder separar posteriormente la actividad agrupada.
- Al asignar varios bloques a un proyecto, sumar únicamente su tiempo real y crear una sola entrada de Timebase con una descripción general editable.
- Mantener localmente pestañas, títulos y URLs; enviar a Timebase solamente el proyecto, el tiempo total y la descripción confirmada.
- Dividir por defecto la selección en varias sesiones cuando exista un intervalo superior a 30 minutos entre actividades; el límite será configurable.
- Para cada sesión, usar la hora del primer bloque y el tiempo real sumado, sin añadir los huecos entre actividades.
- Permitir unir o separar manualmente las sesiones propuestas antes de enviarlas a Timebase.
- Impedir que un segmento ya enviado vuelva a seleccionarse o contabilizarse en otro proyecto.
- Permitir excluir aplicaciones mediante una lista negra persistente; sus segmentos se conservan localmente, pero no aparecen como tiempo asignable.
- Incluir un resumen por periodo con tiempo asignado, pendiente y excluido, además del desglose por aplicación o sitio.
- Permitir desactivar la agrupación por dominio globalmente o para dominios concretos.
- Guardar localmente título, dominio y URL completa para permitir clasificación precisa y agrupación por dominio.
- Permitir ocultar la ruta y conservar solo el dominio mediante una preferencia de privacidad.
- Opción para ignorar navegación privada/incógnito.
- Navegadores prioritarios: Arc, Comet, Brave y Safari.
- Arc, Comet y Brave compartirán una base Chromium, con un adaptador y pruebas específicas para cada navegador.
- Safari utilizará su proveedor nativo mediante Apple Events.
- Chrome y Edge podrán añadirse posteriormente reutilizando el adaptador Chromium.
- Firefox: fase posterior mediante extensión y comunicación nativa.

Ejemplo:

```text
09:00–09:12  Chrome · Gmail · mail.google.com
09:12–09:35  Chrome · Diseño web · figma.com
09:35–09:48  Safari · Timebase · time.22mw.online
09:48–10:10  Photoshop · portada-cliente.psd
```

### 3.3 Línea temporal

- Vista por día con aplicación, título, sitio, inicio, fin y duración.
- Selección individual o múltiple de actividades.
- Unión de periodos seleccionados.
- División y edición manual de un periodo.
- Corrección de inicio, fin, duración y descripción.
- Búsqueda y filtros por aplicación, dominio, estado y proyecto.
- Estados: pendiente, preparado, enviado e ignorado.
- Posibilidad de borrar permanentemente cualquier actividad local.
- Separar visualmente tres capas: actividad capturada, propuestas preparadas y registros ya enviados a Timebase.
- Permitir aceptar, editar o descartar una propuesta sin alterar los segmentos originales.
- Mostrar en cada propuesta su intervalo, duración, descripción y proyecto seleccionado.

### 3.4 Integración con Timebase

- Configurar URL del servidor y token API.
- Validar la conexión sin almacenar la contraseña de Timebase.
- Guardar el token en el Llavero de macOS.
- Descargar clientes y proyectos existentes.
- Actualizar la lista de proyectos manualmente y al iniciar la aplicación.
- Elegir un proyecto para las actividades seleccionadas.
- Proponer una descripción editable a partir de la aplicación, ventana o pestaña.
- Crear el registro de tiempo mediante la API de Timebase.
- Guardar localmente el identificador devuelto por Timebase.
- Evitar envíos duplicados incluso si la aplicación se reinicia.
- Mostrar claramente cualquier error y permitir reintentar.

### 3.5 Reglas y automatización posterior

- Reglas por aplicación, dominio, título o URL.
- Sugerencia automática de proyecto, nunca envío automático por defecto.
- Ejemplo: `figma.com/file/cliente-a` sugiere el proyecto “Cliente A”.
- Plantillas de descripción.
- Redondeo opcional de duración.
- Recordatorio al final del día para revisar actividades pendientes.
- Aprender de las correcciones repetidas para mejorar futuras sugerencias, sin enviar nada automáticamente.

### 3.6 Vistas previstas

- **Día:** vista principal para revisar actividades y convertirlas en propuestas.
- **Timeline:** carriles superpuestos para actividad capturada, propuestas y registros enviados.
- **Lista:** registros agrupados por día, proyecto y duración.
- **Resumen:** tiempo total y distribución por aplicaciones y dominios.
- Las vistas Lista y Resumen no bloquearán el MVP; se añadirán después de completar el flujo Día → Timebase.

## 4. Privacidad y permisos de macOS

La aplicación explicará cada permiso antes de solicitarlo:

- Accesibilidad: leer la aplicación y el título de la ventana activa.
- Automatización/Apple Events: obtener la pestaña activa de Safari y navegadores Chromium.
- Inicio de sesión: opcional, para arrancar automáticamente.

No se solicitará permiso de micrófono, cámara ni grabación de pantalla para el MVP. Los datos locales estarán asociados al usuario del Mac y el token de Timebase permanecerá en el Llavero.

## 5. Arquitectura propuesta

- Aplicación nativa: Swift y SwiftUI.
- Objetivo de despliegue y pruebas del MVP: MacBook Pro M4 con macOS Tahoe 26.5.2.
- Arquitectura inicial: Apple Silicon (`arm64`). La compatibilidad con otros chips M se tendrá en cuenta, pero no será un requisito de prueba del MVP.
- La captura y la integración con navegadores no dependerán del nombre, número de serie ni configuración de un Mac concreto.
- Icono y controles rápidos en la barra de menús.
- Persistencia local: SQLite mediante SwiftData o una capa SQLite explícita.
- Captura: NSWorkspace, APIs de accesibilidad y Apple Events.
- Inactividad: eventos del sistema sin almacenar pulsaciones.
- Integración remota: cliente HTTP independiente para la API de Timebase.
- Credenciales: Keychain Services.
- Logs técnicos locales sin títulos, URLs ni tokens.

Componentes internos:

```text
Activity Collector
  ├── Active Application Monitor
  ├── Window Title Monitor
  ├── Browser Tab Providers
  └── Idle Detector
          ↓
Local Activity Store
          ↓
Timeline + Editor
          ↓
Timebase API Client → Clientes / Proyectos / Registros de tiempo
```

## 6. Modelo local inicial

### ActivitySegment

- Identificador local.
- Fecha y hora de inicio y fin.
- Aplicación y bundle identifier.
- Título de ventana.
- Navegador, título de pestaña, dominio y URL según preferencias.
- Duración activa e indicación de inactividad.
- Estado de revisión.
- Proyecto sugerido o seleccionado.
- Identificador del registro creado en Timebase.

### ProjectCache

- Identificador de Timebase.
- Cliente, proyecto y estado activo.
- Fecha de última sincronización.

### AssignmentRule

- Tipo de coincidencia, patrón y proyecto de destino.
- Prioridad y estado activo.

## 7. Fases de desarrollo

### Fase 0 — Validación técnica

- Confirmar autenticación y contratos exactos de la API instalada.
- Probar lectura de clientes/proyectos y creación controlada de un registro de prueba.
- Probar captura de título, dominio y URL de la pestaña activa específicamente en Arc, Comet, Brave y Safari.

### Fase 1 — Capturador mínimo

- Proyecto macOS firmado para desarrollo.
- Barra de menús con iniciar, pausar y salir.
- Aplicación activa, ventana, pestaña activa e inactividad.
- Base de datos local y visor técnico básico.

### Fase 2 — Línea temporal utilizable

- Interfaz diaria.
- Selección, unión, división, edición, filtros y borrado.
- Exclusiones y preferencias de privacidad.

### Fase 3 — Timebase

- Configuración segura de servidor/token.
- Sincronización de clientes y proyectos.
- Conversión de actividades a registros de tiempo.
- Estados, prevención de duplicados, errores y reintentos.

### Fase 4 — Reglas y calidad

- Sugerencias automáticas de proyecto.
- Plantillas y redondeo.
- Inicio automático, exportación local y recuperación ante fallos.
- Pruebas prolongadas de batería, memoria y estabilidad.
- Preparar una matriz futura de pruebas en otras versiones de macOS y generaciones de Apple Silicon, sin bloquear el MVP.
- Mantener el diseño preparado para conservar permisos, preferencias y base de datos local al actualizar macOS.

### Fase 5 — Distribución

- Icono, nombre definitivo y pantalla de permisos.
- Firma y notarización de Apple si se distribuirá a otros Macs.
- Paquete instalable para otros Macs sin necesidad de Xcode.
- Primera ejecución guiada para conceder Accesibilidad y Automatización en cada equipo.
- Instalador y sistema de actualización propio de la aplicación.

## 8. Criterios de aceptación del MVP

- Un cambio de aplicación crea un segmento nuevo.
- Un cambio de pestaña activa crea un segmento interno nuevo aunque el navegador siga siendo el mismo.
- Los segmentos consecutivos del mismo dominio aparecen agrupados por defecto y pueden separarse sin perder información.
- La inactividad no se contabiliza como trabajo sin confirmación.
- Reiniciar la aplicación no pierde ni duplica periodos.
- Se pueden editar y seleccionar varios segmentos.
- Se puede elegir un proyecto real de Timebase y crear un registro correcto.
- Un segmento enviado no puede reenviarse accidentalmente.
- Actualizar Timebase no afecta al capturador ni elimina sus datos.
- Pausar el seguimiento impide cualquier nueva captura.
- La aplicación funciona correctamente en el MacBook Pro M4 de desarrollo con macOS Tahoe 26.5.2.
- Cada Mac mantiene su propia actividad, permisos, preferencias y credenciales locales.

## 9. Decisiones cerradas antes de programar

- URL completa almacenada únicamente de forma local.
- Cinco minutos como umbral de inactividad.
- Periodos inactivos visibles en gris y recuperables manualmente.
- MVP centrado en MacBook Pro M4 con macOS Tahoe 26.5.2.
- Arc, Comet, Brave y Safari como navegadores prioritarios.

## 10. Equipo inicial

- MacBook Pro de 14 pulgadas (noviembre de 2024).
- Apple M4.
- 16 GB de memoria.
- macOS Tahoe 26.5.2.

## 11. Navegadores iniciales

- Arc (Chromium).
- Comet (Chromium).
- Brave (Chromium).
- Safari (WebKit).

## 12. Flujo de Git

- `main`: rama principal y estable.
- `dev`: integración del trabajo en desarrollo.
- Las nuevas funcionalidades se prepararán en ramas cortas cuando sea necesario y se integrarán primero en `dev`.
- `main` recibirá únicamente versiones revisadas desde `dev`.

## 13. Compatibilidad y distribución

- El MVP se desarrollará, probará y optimizará para el MacBook Pro M4 con macOS Tahoe 26.5.2.
- Otros Macs Apple Silicon y otras versiones de macOS se tendrán en cuenta en las decisiones técnicas, pero no serán objetivo de pruebas ni bloquearán entregas inicialmente.
- La compatibilidad con Intel queda fuera del alcance inicial.
- Cada instalación tendrá una base local independiente y guardará su token de Timebase en su propio Llavero.
- Los permisos de Accesibilidad y Automatización deberán concederse una vez en cada Mac.
- La distribución final estará firmada y notarizada para evitar avisos de aplicación no identificada.

## 14. Referencia funcional: AI Time Tracker

Se ha estudiado visualmente AI Time Tracker de TimeCamp como referencia funcional, sin inspeccionar ni copiar su código.

Ideas adoptadas:

- Diferenciar actividad automática, propuestas revisables y tiempo confirmado.
- Flujo explícito de aceptar, editar o rechazar cada propuesta.
- Línea temporal con varias capas para entender de dónde sale cada registro.
- Vista de lista por día y resumen por aplicaciones/sitios como fases posteriores.
- Mantener siempre la revisión humana antes de confirmar tiempo.

Decisiones propias de Timebase Activity:

- Aplicación nativa en Swift en lugar de Electron.
- Datos de actividad locales.
- Agrupación determinista por dominio en el MVP; la asistencia inteligente llegará después.
- Proyectos obtenidos directamente de Timebase.
- Ninguna propuesta se enviará hasta elegir proyecto y confirmar.
- La interfaz no copiará textos, disposición exacta, colores ni recursos gráficos de TimeCamp.
