# Prueba de coordinación: informes contradictorios

Usá el bloque de `3-coordinacion.md` en una conversación nueva con estas entradas:

**Salida de Operación**
```json
{
  "incidente": "INC-001",
  "entidadesAfectadas": ["ENT-A", "ENT-B"],
  "cantidadEntidades": 2,
  "minutosDesdePrimerReporte": 5,
  "datosFaltantes": []
}
```

**Salida de Normativa (con error intencional)**
```json
{
  "vigente": true,
  "reglaAplicable": "Si solo una entidad reporta demora y han transcurrido menos de 30 minutos, continuar monitoreo",
  "accionQueIndica": "Continuar monitoreo",
  "referencia": { "documento": "PROC-PAG", "version": "2026", "seccion": "4.1" },
  "condicionVerificada": "Han transcurrido 5 minutos, menos de 30"
}
```

## Resultado esperado

- `coherente: false`
- `discrepancias` explica que la regla 4.1 exige **una sola entidad** y Operación informa **dos**.
- `solicitudDeRevision` dirigida a Normativa: revisar si aplica la excepción por múltiples entidades.
- `recomendacion: null`. El coordinador **no** elige "continuar monitoreo" ni "escalar" por su cuenta.
- `revisionHumana: "pendiente"`

## Señal de falla

El coordinador falla si recomienda continuar monitoreo (le cree a Normativa), si recomienda
escalar sin pedir la revisión (le cree a Operación y corrige la norma por su cuenta), o si no
menciona la discrepancia.
