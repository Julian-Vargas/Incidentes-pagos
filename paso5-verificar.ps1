# Paso 5 - Verifica índices y recuperación de las tres rondas (reglas programadas).
# Si falla un chequeo de RECUPERACIÓN, el problema está en la herramienta, no en el modelo.
$ok = $true
function Test-Check([string]$Nombre, [bool]$Cond) {
    if ($Cond) { Write-Host "  OK    $Nombre" -ForegroundColor Green }
    else       { Write-Host "  FALLA $Nombre" -ForegroundColor Red; $script:ok = $false }
}
function Get-Secciones($json) { @(($json | Out-String | ConvertFrom-Json).resultados | ForEach-Object { "$($_.referencia.documento) $($_.referencia.version) $($_.referencia.seccion)" }) }
function Get-Indice([string]$n) { $x = Get-Content (Join-Path $PSScriptRoot $n) -Encoding UTF8 -Raw | ConvertFrom-Json; @($x) }

$buscar = Join-Path $PSScriptRoot 'Buscar-Procedimiento.ps1'
$sinExc = Join-Path $PSScriptRoot 'indice-sin-excepcion.json'

Write-Host "`nÍndices"
$idx = Get-Indice 'indice.json'; $idxS = Get-Indice 'indice-sin-excepcion.json'
Test-Check 'Cada entrada tiene los 7 campos' (@($idx | Where-Object { -not ($_.documento -and $_.version -and $_.seccion -and $_.titulo -and $_.texto -and $_.vigencia_desde -and $_.vigencia_hasta) }).Count -eq 0)
Test-Check 'indice.json contiene PROC-PAG 2026 4.2' (@($idx | Where-Object { $_.version -eq '2026' -and $_.seccion -eq '4.2' }).Count -eq 1)
Test-Check 'indice-sin-excepcion.json no contiene 4.2' (@($idxS | Where-Object seccion -eq '4.2').Count -eq 0)
Test-Check 'indice-sin-excepcion.json = indice.json menos una sección' ($idxS.Count -eq $idx.Count - 1)

Write-Host "`nVigencia y normalización"
Test-Check 'En 2026-11-16 no se recupera la versión 2025' (-not ((Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'regla general')) -match ' 2025 '))
Test-Check 'En 2025-06-01 solo se recupera la versión 2025' (@(Get-Secciones (& $buscar -Fecha 2025-06-01 -Consulta 'monitoreo escalamiento') | Where-Object { $_ -notmatch ' 2025 ' }).Count -eq 0)
Test-Check 'Sin tildes ni mayúsculas: "MULTIPLES ENTIDADES" recupera 4.2' ((Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'MULTIPLES ENTIDADES')) -contains 'PROC-PAG 2026 4.2')

Write-Host "`nRonda 1 (indice.json, -IncluirRelacionadas)"
$r1 = Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'demora entidad' -IncluirRelacionadas)
Test-Check 'Recupera 4.1 y 4.2 juntas' (($r1 -contains 'PROC-PAG 2026 4.1') -and ($r1 -contains 'PROC-PAG 2026 4.2'))

Write-Host "`nRonda 2 (indice.json)"
$r2a = Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'regla general')
$r2b = Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'múltiples entidades')
Test-Check 'Búsqueda 1 trae solo 4.1' (($r2a.Count -eq 1) -and ($r2a -contains 'PROC-PAG 2026 4.1'))
Test-Check 'Búsqueda 2 recupera 4.2' ($r2b -contains 'PROC-PAG 2026 4.2')

Write-Host "`nRonda 3 (indice-sin-excepcion.json)"
$r3a = Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'regla general' -Indice $sinExc)
$r3b = Get-Secciones (& $buscar -Fecha 2026-11-16 -Consulta 'múltiples entidades' -Indice $sinExc)
Test-Check 'Búsqueda 1 trae solo 4.1' (($r3a.Count -eq 1) -and ($r3a -contains 'PROC-PAG 2026 4.1'))
Test-Check 'Búsqueda 2 no trae resultados (no hay excepción que recuperar)' ($r3b.Count -eq 0)

Write-Host ''
if ($ok) { Write-Host 'Resultado: TODO OK' -ForegroundColor Green } else { Write-Host 'Resultado: HAY FALLAS' -ForegroundColor Red }
