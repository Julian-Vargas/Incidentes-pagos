# Paso 1 - Recorrido del triaje: flujo fijo vs. decisiones del agente
# Cian     = paso fijo (regla programada)
# Amarillo = punto donde decide el agente

$fijo   = 'Cyan'
$agente = 'Yellow'

function Write-Paso {
    param([string]$Texto, [string]$Color, [string]$Etiqueta)
    Write-Host ("  [{0}] " -f $Etiqueta) -ForegroundColor $Color -NoNewline
    Write-Host $Texto -ForegroundColor $Color
}

function Write-Flecha { Write-Host '        |' ; Write-Host '        v' }

Write-Host ''
Write-Host 'Recorrido del triaje de incidentes de pagos' -ForegroundColor White
Write-Host ''
Write-Host '  Leyenda: ' -NoNewline
Write-Host 'FIJO = regla programada' -ForegroundColor $fijo -NoNewline
Write-Host '   |   ' -NoNewline
Write-Host 'AGENTE = decisión del agente' -ForegroundColor $agente
Write-Host ''

Write-Paso '1. Recibir la alerta del incidente'                      $fijo   'FIJO  '
Write-Flecha
Write-Paso '2. Abrir el caso'                                        $fijo   'FIJO  '
Write-Flecha
Write-Paso '3. Elegir qué consultar según los datos recibidos'       $agente 'AGENTE'
Write-Flecha
Write-Paso '4. Interpretar la evidencia: ¿alcanza o falta otra consulta?' $agente 'AGENTE'
Write-Host '        |   (si falta evidencia, vuelve al paso 3)' -ForegroundColor $agente
Write-Host '        v'
Write-Paso '5. Proponer una recomendación con su evidencia'          $agente 'AGENTE'
Write-Flecha
Write-Paso '6. Revisión humana: una persona decide si se comunica'   $fijo   'FIJO  '
Write-Host ''
