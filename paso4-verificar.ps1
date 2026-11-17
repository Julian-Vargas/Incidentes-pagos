# Paso 4 - Verifica el estado de INC-001 contra los criterios CA1..CA5 (reglas programadas)
param([string]$Estado = (Join-Path $PSScriptRoot 'estado-INC-001.json'))

$ok = $true
function Test-Check([string]$Nombre, [bool]$Cond) {
    if ($Cond) { Write-Host "  OK    $Nombre" -ForegroundColor Green }
    else       { Write-Host "  FALLA $Nombre" -ForegroundColor Red; $script:ok = $false }
}

$e = Get-Content $Estado -Encoding UTF8 -Raw | ConvertFrom-Json
$momento = [datetime]::ParseExact("$($e.fechaEvaluacion) $($e.horaEvaluacion)", 'yyyy-MM-dd HH:mm', $null)

# CA1 - Vigencia
Write-Host "`nCA1 Vigencia"
$ref = @($e.referencias)[0]
Test-Check 'Referencia PROC-PAG 2026 4.2' ($ref.documento -eq 'PROC-PAG' -and $ref.version -eq '2026' -and $ref.seccion -eq '4.2')
$doc = Join-Path $PSScriptRoot "procedimiento-$($ref.version).txt"
$texto = Get-Content $doc -Encoding UTF8 -Raw
if ($texto -match 'Vigencia:\s*(\d{4}-\d{2}-\d{2})\s*a\s*(\d{4}-\d{2}-\d{2})') {
    $desde = [datetime]$Matches[1]; $hasta = ([datetime]$Matches[2]).AddDays(1)
    Test-Check "Versión vigente el $($momento.ToString('yyyy-MM-dd HH:mm'))" ($momento -ge $desde -and $momento -lt $hasta)
} else { Test-Check 'El documento declara vigencia' $false }

# CA2 - Conteo independiente desde la bitácora (hasta la hora de evaluación)
Write-Host "`nCA2 Conteo de entidades"
$filas = @(Import-Csv (Join-Path $PSScriptRoot 'bitacora.csv') -Encoding UTF8 |
    Where-Object { $_.incidente.Trim() -eq $e.incidente -and [datetime]::ParseExact($_.hora.Trim(), 'HH:mm', $null).TimeOfDay -le $momento.TimeOfDay })
$distintas = @($filas | ForEach-Object { $_.entidad.Trim().ToUpper() } | Sort-Object -Unique)
$primero   = @($filas | ForEach-Object { $_.hora.Trim() } | Sort-Object)[0]
Test-Check "entidadesDistintas = $($distintas.Count)" ($e.entidadesDistintas -eq $distintas.Count)
Test-Check "primerReporte = $primero"                 ($e.primerReporte -eq $primero)

# CA3 - Referencias exactas
Write-Host "`nCA3 Referencias exactas"
foreach ($r in @($e.referencias)) {
    Test-Check "Campos completos ($($r.documento) $($r.version) $($r.seccion))" ($r.documento -and $r.version -and $r.seccion)
    $t = Get-Content (Join-Path $PSScriptRoot "procedimiento-$($r.version).txt") -Encoding UTF8 -Raw
    Test-Check "Sección $($r.seccion) existe en procedimiento-$($r.version).txt" ($t -match "(?m)^$([regex]::Escape($r.seccion))\s")
}

# CA4 - Evidencia y límite de búsquedas
Write-Host "`nCA4 Evidencia y límite"
Test-Check 'Búsquedas documentales <= 2' ($e.busquedasDocumentales.usadas -le 2)
Test-Check 'Búsquedas declaradas = consultas documentales registradas' ($e.busquedasDocumentales.usadas -eq @($e.consultasRealizadas | Where-Object cuentaComoBusquedaDocumental).Count)
if ($e.evidenciaInsuficiente) { Test-Check 'Sin recomendación y con pendientes' ($null -eq $e.recomendacion -and @($e.pendientes).Count -ge 1) }
else                          { Test-Check 'Recomendación con referencia y sin pendientes' ($e.recomendacion -and @($e.referencias).Count -ge 1 -and @($e.pendientes).Count -eq 0) }

# CA5 - Revisión humana
Write-Host "`nCA5 Revisión humana"
Test-Check 'Etapa en_revision_humana' ($e.etapa -eq 'en_revision_humana')
Test-Check 'decisionHumana vacía (la decide una persona)' ($null -eq $e.decisionHumana)

Write-Host ''
if ($ok) { Write-Host 'Resultado: TODO OK' -ForegroundColor Green } else { Write-Host 'Resultado: HAY FALLAS' -ForegroundColor Red }
