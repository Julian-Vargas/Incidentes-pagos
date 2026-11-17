# Paso 6 - Compara los resultados de las 4 pruebas con lo esperado (reglas programadas).
$script:lineas = New-Object System.Collections.ArrayList
$script:ok = $true
function Out-Linea([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c; [void]$script:lineas.Add($t) }
function Test-Check([string]$Nombre, [bool]$Cond) {
    if ($Cond) { Out-Linea "  OK    $Nombre" 'Green' } else { Out-Linea "  FALLA $Nombre" 'Red'; $script:ok = $false }
}
function Get-Prueba($n) {
    $raw = Get-Content (Join-Path $PSScriptRoot "resultados\prueba-$n.json") -Encoding UTF8 -Raw
    @{ raw = $raw; o = ($raw | ConvertFrom-Json) }
}
function Get-Ref($r) { "$($r.documento) $($r.version) $($r.seccion)" }

function Test-Comunes($p) {
    $o = $p.o
    Test-Check 'Revisión humana pendiente'               ($o.revisionHumana.estado -eq 'pendiente' -and $null -eq $o.decisionHumana)
    Test-Check 'Búsquedas documentales <= 2 y detalladas' ($o.busquedasDocumentales.usadas -le 2 -and @($o.busquedasDocumentales.detalle).Count -eq $o.busquedasDocumentales.usadas)
    Test-Check '"recuperado" siempre es lista JSON'       (([regex]::Matches($p.raw, '"recuperado":\s*\[')).Count -eq $o.busquedasDocumentales.usadas)
    $recuperadas = @($o.busquedasDocumentales.detalle | ForEach-Object { @($_.recuperado) } | ForEach-Object { Get-Ref $_ })
    foreach ($r in @($o.referencias)) {
        Test-Check "Trazabilidad: la cita $(Get-Ref $r) fue recuperada" ($recuperadas -contains (Get-Ref $r))
    }
}

Out-Linea "Prueba final - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Out-Linea "`n1. Incidente principal: INC-001, 2026-11-16, 09:20"
$p = Get-Prueba 1; $o = $p.o
Test-Check '2 entidades afectadas'                      ($o.entidadesDistintas -eq 2)
Test-Check 'Escalar a Coordinación de Pagos'           ($o.accion -eq 'escalar' -and $o.destinatario -eq 'Coordinación de Pagos')
Test-Check 'Cita exactamente PROC-PAG 2026 4.2'         ((@($o.referencias) | ForEach-Object { Get-Ref $_ }) -join ';' -eq 'PROC-PAG 2026 4.2')
Test-Check 'Etapa en_revision_humana'                   ($o.etapa -eq 'en_revision_humana')
Test-Comunes $p

Out-Linea "`n2. Caso de control: INC-002, 2026-11-16, 10:10"
$p = Get-Prueba 2; $o = $p.o
Test-Check '1 entidad y 10 minutos'                     ($o.entidadesDistintas -eq 1 -and $o.evidencia.minutosDesdePrimerReporte -eq 10)
Test-Check 'Continuar monitoreo'                        ($o.accion -eq 'continuar_monitoreo')
Test-Check 'Cita exactamente PROC-PAG 2026 4.1'         ((@($o.referencias) | ForEach-Object { Get-Ref $_ }) -join ';' -eq 'PROC-PAG 2026 4.1')
Test-Comunes $p

Out-Linea "`n3. Consulta histórica: INC-001, 2025-11-16, 09:20"
$p = Get-Prueba 3; $o = $p.o
$vers = @($o.busquedasDocumentales.detalle | ForEach-Object { @($_.recuperado) } | ForEach-Object { $_.version } | Select-Object -Unique)
Test-Check 'Recupera solo la versión 2025'              ($vers.Count -eq 1 -and $vers[0] -eq '2025')
Test-Check 'Continuar monitoreo con 5 minutos'          ($o.accion -eq 'continuar_monitoreo' -and $o.evidencia.minutosDesdePrimerReporte -eq 5)
Test-Check 'Cita exactamente PROC-PAG 2025 4.1'         ((@($o.referencias) | ForEach-Object { Get-Ref $_ }) -join ';' -eq 'PROC-PAG 2025 4.1')
Test-Comunes $p

Out-Linea "`n4. Evidencia insuficiente: INC-001, 2026-11-16, 09:20, indice-sin-excepcion.json"
$p = Get-Prueba 4; $o = $p.o
Test-Check 'Estado evidencia insuficiente'              ($o.evidenciaInsuficiente -and $o.etapa -eq 'evidencia_insuficiente')
Test-Check 'Lista las dos búsquedas hechas'             (@($o.busquedasDocumentales.detalle).Count -eq 2 -and $o.busquedasDocumentales.usadas -eq 2)
Test-Check 'No aplica 4.1: sin recomendación ni cita'   ($null -eq $o.recomendacion -and $null -eq $o.accion -and @($o.referencias).Count -eq 0)
Test-Check 'Pendiente: regla para múltiples entidades'  (@($o.pendientes | Where-Object { $_ -match 'dos o m.s entidades' }).Count -ge 1)
Test-Comunes $p

Out-Linea ''
if ($script:ok) { Out-Linea 'Resultado: TODO OK' 'Green' } else { Out-Linea 'Resultado: HAY FALLAS' 'Red' }
[IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'resultado-pruebas.txt'), [string[]]$script:lineas, (New-Object Text.UTF8Encoding $true))
