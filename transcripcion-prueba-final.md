# Transcripción de la prueba final: triaje de incidentes de pagos

Ejecutado el 2026-11-17 con PowerShell 5.1, sin dependencias externas y con datos ficticios.

**Convención de etiquetas**
- **[Regla programada]**: lo hace un script siempre igual (consultar la bitácora, filtrar por vigencia, dejar la revisión humana pendiente).
- **[Decisión del agente]**: lo eligió el agente según la evidencia (qué buscar, si hace falta otra búsqueda, qué sección aplica).

Límite: máximo 2 búsquedas documentales por caso. La consulta a la bitácora no cuenta.

---

## Prueba 1: Incidente principal (INC-001, 2026-11-16, 09:20)

**[Regla programada] Bitácora**
```
> .\Consultar-Bitacora.ps1 -Incidente INC-001
{"incidente":"INC-001","reportes":3,"entidadesDistintas":["ENT-A","ENT-B"],"primerReporte":"09:15"}
Minutos desde el primer reporte: 5
```

**[Decisión del agente] Búsqueda 1 de 2**: pedir la regla general junto con sus excepciones.
```
> .\Buscar-Procedimiento.ps1 -Fecha 2026-11-16 -Consulta "regla general demora entidad" -IncluirRelacionadas
-> PROC-PAG 2026 4.1 [coincidencia] Si solo una entidad reporta demora y han transcurrido menos de 30 minutos
   desde el primer reporte, continuar monitoreo. A partir de 30 minutos, recomendar escalamiento a Coordinación de Pagos.
-> PROC-PAG 2026 4.2 [relacionada (excepción)] Si dos o más entidades distintas reportan demoras en el mismo
   incidente, recomendar escalamiento inmediato a Coordinación de Pagos.
```

**[Decisión del agente] Conclusión**: la 4.1 exige una sola entidad y hay dos. Se cumple la condición de la
4.2. No hace falta una segunda búsqueda.

**Recomendación:** escalamiento inmediato a Coordinación de Pagos (PROC-PAG, versión 2026, sección 4.2).
**Estado:** `en_revision_humana`, revisión humana **pendiente** (PROC-PAG 2026, sección 4.3).

---

## Prueba 2: Caso de control (INC-002, 2026-11-16, 10:10)

**[Regla programada] Bitácora**
```
> .\Consultar-Bitacora.ps1 -Incidente INC-002
{"incidente":"INC-002","reportes":1,"entidadesDistintas":["ENT-C"],"primerReporte":"10:00"}
Minutos desde el primer reporte: 10
```

**[Decisión del agente] Búsqueda 1 de 2**
```
> .\Buscar-Procedimiento.ps1 -Fecha 2026-11-16 -Consulta "regla general demora entidad" -IncluirRelacionadas
-> PROC-PAG 2026 4.1 [coincidencia] Si solo una entidad reporta demora y han transcurrido menos de 30 minutos ...
-> PROC-PAG 2026 4.2 [relacionada (excepción)] Si dos o más entidades distintas reportan demoras ...
```

**[Decisión del agente] Conclusión**: una entidad (ENT-C) y 10 minutos, menos de 30. Se cumple la 4.1 y
no la 4.2.

**Recomendación:** continuar el monitoreo (PROC-PAG, versión 2026, sección 4.1).
**Estado:** `en_revision_humana`, revisión humana **pendiente** (PROC-PAG 2026, sección 4.3).

---

## Prueba 3: Consulta histórica (INC-001, 2025-11-16, 09:20)

**[Regla programada] Bitácora**
```
> .\Consultar-Bitacora.ps1 -Incidente INC-001
{"incidente":"INC-001","reportes":3,"entidadesDistintas":["ENT-A","ENT-B"],"primerReporte":"09:15"}
Minutos desde el primer reporte: 5
```
Nota: la bitácora registra solo horas, sin fecha. Las horas se toman como si fueran del 2025-11-16.

**[Decisión del agente] Búsqueda 1 de 2** (el filtro por vigencia deja solo 1 sección vigente)
```
> .\Buscar-Procedimiento.ps1 -Fecha 2025-11-16 -Consulta "regla general demora entidad" -IncluirRelacionadas
-> PROC-PAG 2025 4.1 [coincidencia] Continuar monitoreo antes de los 30 minutos desde el primer reporte.
   A partir de 30 minutos, recomendar escalamiento a Coordinación de Pagos.
```

**[Decisión del agente] Conclusión**: en esa fecha solo está vigente la versión 2025, que no tiene excepción
por múltiples entidades y cuya 4.1 no depende de la cantidad de entidades. Con 5 minutos, menos de 30,
corresponde continuar el monitoreo.

**Recomendación:** continuar el monitoreo (PROC-PAG, versión 2025, sección 4.1).
**Estado:** `en_revision_humana`, revisión humana **pendiente**. Es una regla programada del flujo, porque la
versión 2025 no tiene sección 4.3.

---

## Prueba 4: Evidencia insuficiente (INC-001, 2026-11-16, 09:20, `indice-sin-excepcion.json`)

**[Regla programada] Bitácora**: 2 entidades (ENT-A, ENT-B), primer reporte 09:15, 5 minutos.

**[Decisión del agente] Búsqueda 1 de 2**
```
> .\Buscar-Procedimiento.ps1 -Fecha 2026-11-16 -Consulta "regla general demora entidad" -Indice .\indice-sin-excepcion.json -IncluirRelacionadas
-> PROC-PAG 2026 4.1 [coincidencia] Si solo una entidad reporta demora y han transcurrido menos de 30 minutos ...
```
La 4.1 exige una sola entidad y hay dos, así que no cubre el caso. Se usa la segunda búsqueda.

**[Decisión del agente] Búsqueda 2 de 2**
```
> .\Buscar-Procedimiento.ps1 -Fecha 2026-11-16 -Consulta "múltiples entidades" -Indice .\indice-sin-excepcion.json -IncluirRelacionadas
"resultados": []
```

**[Decisión del agente] Conclusión**: **evidencia insuficiente**. Se agotaron las búsquedas (2 de 2). No se aplica
la 4.1 como si cubriera el caso y no hay recomendación.

**Pendiente para la revisión humana:** confirmar si existe una regla vigente para dos o más entidades que
reportan demora en el mismo incidente.
**Estado:** `evidencia_insuficiente`, revisión humana **pendiente** (PROC-PAG 2026, sección 4.3).

---

## Resumen

| Prueba | Acción | Referencia | Búsquedas | Estado |
|---|---|---|---|---|
| 1. INC-001, 2026 | Escalar a Coordinación de Pagos | PROC-PAG 2026 §4.2 | 1 de 2 | Pendiente de revisión humana |
| 2. INC-002, 2026 | Continuar monitoreo | PROC-PAG 2026 §4.1 | 1 de 2 | Pendiente de revisión humana |
| 3. INC-001, 2025 | Continuar monitoreo | PROC-PAG 2025 §4.1 | 1 de 2 | Pendiente de revisión humana |
| 4. INC-001, sin excepción | Ninguna (evidencia insuficiente) | — | 2 de 2 | Pendiente de revisión humana |

Verificación automática: `.\paso6-verificar.ps1` da 29 de 29 chequeos en OK (ver `resultado-pruebas.txt`).
Los resultados completos están en `resultados\prueba-1.json` a `resultados\prueba-4.json`.

**Incidencia durante la ejecución:** en una primera corrida, el script auxiliar que guarda los resultados
estaba sin BOM. PowerShell 5.1 leyó mal las tildes y la búsqueda «múltiples entidades» se hizo con texto
alterado. Se detectó al revisar la salida, se guardó el script en UTF-8 con BOM y se repitieron las
cuatro pruebas. Los resultados de esta transcripción son los de la segunda corrida.
