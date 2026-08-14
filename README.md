# Timebase Activity para macOS

Aplicación complementaria para registrar actividad local en macOS, revisar una línea temporal y convertir periodos seleccionados en registros asociados a proyectos de Timebase.

El proyecto está en fase de planificación. Consulta [PLAN_DESARROLLO.md](PLAN_DESARROLLO.md) para ver el alcance acordado y las fases previstas.

Los primeros resultados sobre navegadores, entorno macOS y API están en [VALIDACION_TECNICA.md](VALIDACION_TECNICA.md).

Aunque el nombre inicial del repositorio contiene `iosapp`, el primer objetivo es una aplicación nativa para macOS.

## Prototipo técnico

El primer prototipo de consola detecta la aplicación y ventana frontales, la pestaña activa en los navegadores validados y el tiempo de inactividad. No guarda ni envía datos.

Compilación:

```bash
swift build
```

Una única lectura controlada:

```bash
swift run timebase-activity-probe --once
```

Seguimiento temporal hasta pulsar `Control+C`:

```bash
swift run timebase-activity-probe
```
