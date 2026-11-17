# Especificación: triaje de incidentes de pagos

## 1. Objetivo

Ante una alerta de incidente de pagos, el agente reúne evidencia mínima y suficiente
(bitácora y procedimiento vigente) y entrega una recomendación fundamentada **o** declara
evidencia insuficiente. La decisión de comunicar el incidente siempre la toma una persona.

## 2. Conceptos

| Concepto | Qué es | Dónde vive |
|---|---|---|
| **Contexto** | Lo que el agente recibe en cada consulta (alerta, extracto de bitácora, sección de procedimiento). | En la conversación; no persiste. |
| **Estado** | Lo que registramos del caso actual: etapa, evidencia, consultas hechas y pendientes. | `estado-<ID>.json` |
| **Memoria** | Lo que permite recuperar un caso anterior en otra sesión. | `historico/` (ver sección 8) |

## 3. Entradas

| Entrada | Descripción |
|---|---|
| Alerta | Identificador del incidente y síntoma reportado (p. ej. INC-001: "se reportaron demoras"). |
| Fecha y hora de evaluación | Momento de referencia del análisis (p. ej. 2026-11-16 09:20). |
| `bitacora.csv` | Reportes de entidades sobre el incidente. |
| `procedimiento-<versión>.txt` | Procedimientos de pago, uno por versión. |
| `estado-<ID>.json` | Estado previo del caso, si existe. |

## 4. Salidas

Un resultado de triaje con estos campos (se guardan también en el estado):

| Campo | Contenido |
|---|---|
| `incidente` | Identificador del caso. |
| `fechaEvaluacion`, `horaEvaluacion` | Momento de referencia. |
| `entidadesDistintas` | Cantidad de entidades distintas que reportaron el incidente. |
| `primerReporte` | Fecha y hora del primer reporte en la bitácora. |
| `referencias` | Lista de `{ documento, version, seccion }`. |
| `recomendacion` | Texto de la recomendación, o `null` si la evidencia es insuficiente. |
| `evidenciaInsuficiente` | `true` / `false`. |
| `pendientes` | Datos que faltan para recomendar. |
| `etapa` | Etapa del caso (sección 7). |
| `decisionHumana` | `null` hasta que una persona decide; el agente nunca lo completa. |

## 5. Reglas

- **R1. Límite de búsquedas:** máximo **2 búsquedas documentales** por caso.
  La consulta a la bitácora **no** cuenta como búsqueda documental.
- **R2. Evidencia antes de recomendar:** el agente no recomienda escalar ni no escalar
  sin datos de la bitácora y una referencia de procedimiento vigente.
- **R3. Registro:** cada consulta se registra en el estado y en `registro-decisiones.csv`
  como *Decisión del agente*; los pasos fijos se registran como *Regla programada*.

## 6. Criterios de aceptación

Cada criterio indica entrada, salida esperada y cómo comprobarla.

**CA1. Vigencia del procedimiento**
- Entrada: INC-001, evaluado el 2026-11-16 a las 09:20.
- Salida esperada: se usa la versión del procedimiento vigente en esa fecha y hora;
  la salida incluye la referencia PROC-PAG, versión 2026, sección 4.2.
- Comprobación: `referencias` contiene exactamente `{PROC-PAG, 2026, 4.2}` y ninguna
  referencia a una versión no vigente en esa fecha.

**CA2. Conteo de entidades distintas**
- Entrada: INC-001 y `bitacora.csv`, considerando solo reportes hasta la hora de evaluación.
- Salida esperada: `entidadesDistintas` y `primerReporte` coinciden con el cálculo directo
  sobre la bitácora (valores únicos de la entidad, sin distinguir mayúsculas ni espacios;
  reporte más antiguo).
- Comprobación: un script independiente calcula ambos valores con `Import-Csv` y los
  compara con la salida; deben ser iguales.

**CA3. Referencias exactas**
- Entrada: cualquier salida con `recomendacion` distinta de `null`.
- Salida esperada: cada referencia tiene `documento`, `version` y `seccion`, todos no vacíos,
  y la sección existe en el archivo de esa versión.
- Comprobación: se valida que los tres campos no estén vacíos y se busca el número de
  sección en `procedimiento-<version>.txt`; una referencia incompleta o inexistente hace
  fallar el criterio.

**CA4. Evidencia insuficiente y límite de búsquedas**
- Entrada: INC-001 con solo la alerta (estado actual), o un caso que agotó sus
  2 búsquedas documentales sin encontrar la sección aplicable.
- Salida esperada: `evidenciaInsuficiente = true`, `recomendacion = null`, `pendientes`
  con al menos un dato, y ninguna recomendación de escalar o no escalar.
- Comprobación: se revisan esos tres campos y que `busquedasDocumentales.usadas <= 2`;
  una tercera búsqueda debe ser rechazada.

**CA5. Revisión humana**
- Entrada: cualquier caso que llegue al final del triaje.
- Salida esperada: `etapa = "en_revision_humana"` y `decisionHumana = null`. Solo una
  persona puede completar `decisionHumana` (revisor, decisión, fecha) y pasar a `cerrado`.
- Comprobación: en la salida del agente `decisionHumana` es `null`; un estado `cerrado`
  sin `decisionHumana.revisor` es inválido.

## 7. Etapas del caso

| Etapa | Significado | Quién la asigna |
|---|---|---|
| `abierto` | Alerta recibida y caso creado; sin consultas ejecutadas. | Regla programada |
| `en_investigacion` | Al menos una consulta ejecutada; se reúne evidencia. | Decisión del agente |
| `evidencia_insuficiente` | No hay base para recomendar (o se agotaron las búsquedas). | Decisión del agente |
| `recomendacion_propuesta` | Hay recomendación con referencias completas. | Decisión del agente |
| `en_revision_humana` | Esperando la decisión de una persona. | Regla programada |
| `cerrado` | Una persona decidió y registró su decisión. | Persona |

Transiciones permitidas:

```
abierto -> en_investigacion -> recomendacion_propuesta -> en_revision_humana -> cerrado
                     |                                        ^
                     +--> evidencia_insuficiente -------------+
```

## 8. Archivo de casos cerrados (memoria)

Al pasar un caso a `cerrado`:

1. Copiar `estado-<ID>.json` a `historico/<ID>_<fechaEvaluacion>.json` sin modificarlo.
2. Agregar una fila a `historico/indice.csv` (UTF-8 con BOM) con:
   `incidente, fechaEvaluacion, sintoma, entidadesDistintas, referencias, recomendacion, decisionHumana, archivo`.
3. Borrar el estado activo solo después de verificar que la copia existe y se lee bien.

En una sesión futura, el agente busca en `historico/indice.csv` por síntoma y referencia,
y abre solo el JSON del caso más parecido.
