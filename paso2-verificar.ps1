# Paso 2 - Verifica la especificación y el estado de INC-001 (reglas programadas)
$ok = $true
function Test-Check([string]$Nombre, [bool]$Cond) {
    if ($Cond) { Write-Host "  OK    $Nombre" -ForegroundColor Green }
    else       { Write-Host "  FALLA $Nombre" -ForegroundColor Red; $script:ok = $false }
}

$spec   = Get-Content (Join-Path $PSScriptRoot 'especificacion.md') -Encoding UTF8 -Raw
$estado = Get-Content (Join-Path $PSScriptRoot 'estado-INC-001.json') -Encoding UTF8 -Raw | ConvertFrom-Json

$etapas = 'abierto','en_investigacion','evidencia_insuficiente','recomendacion_propuesta','en_revision_humana','cerrado'

Write-Host "`nEspecificación"
Test-Check 'Tiene 5 criterios de aceptación (CA1..CA5)' (([regex]::Matches($spec, '\*\*CA\d\.')).Count -eq 5)
foreach ($s in 'Objetivo','Entradas','Salidas','Etapas del caso','Archivo de casos cerrados') {
    Test-Check "Tiene sección '$s'" ($spec -match [regex]::Escape($s))
}
Test-Check 'Fija máximo de 2 búsquedas documentales' ($spec -match 'máximo \*\*2 búsquedas documentales\*\*')
foreach ($e in $etapas) { Test-Check "Define la etapa '$e'" ($spec -match "``$e``") }

Write-Host "`nEstado INC-001"
Test-Check 'Identificador INC-001'                    ($estado.incidente -eq 'INC-001')
Test-Check 'Fecha 2026-11-16'                         ($estado.fechaEvaluacion -eq '2026-11-16')
Test-Check 'Hora 09:20'                               ($estado.horaEvaluacion -eq '09:20')
Test-Check 'Etapa "abierto" y definida en la spec'    ($estado.etapa -eq 'abierto' -and $etapas -contains $estado.etapa)
Test-Check 'Tiene evidencia'                          (@($estado.evidencia).Count -ge 1)
Test-Check 'Tiene consultasRealizadas (lista)'        ($null -ne $estado.PSObject.Properties['consultasRealizadas'])
Test-Check 'Búsquedas usadas <= 2 (R1)'               ($estado.busquedasDocumentales.usadas -le 2 -and $estado.busquedasDocumentales.maximo -eq 2)
Test-Check 'CA4: sin evidencia no hay recomendación'  ($estado.evidenciaInsuficiente -and $null -eq $estado.recomendacion -and @($estado.pendientes).Count -ge 1)
Test-Check 'CA5: decisionHumana vacía'                ($null -eq $estado.decisionHumana)

Write-Host ''
if ($ok) { Write-Host 'Resultado: TODO OK' -ForegroundColor Green } else { Write-Host 'Resultado: HAY FALLAS' -ForegroundColor Red }
