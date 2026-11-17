# Construye indice.json (una entrada por sección de cada procedimiento-*.txt)
# e indice-sin-excepcion.json (igual, sin la sección 4.2). Regla programada.
$bom = New-Object System.Text.UTF8Encoding $true
$entradas = @()

foreach ($archivo in Get-ChildItem (Join-Path $PSScriptRoot 'procedimiento-*.txt') | Sort-Object Name) {
    $lineas = Get-Content $archivo.FullName -Encoding UTF8
    $doc = $null; $ver = $null; $desde = $null; $hasta = $null
    $actual = $null

    foreach ($l in $lineas) {
        if     ($l -match '^Documento:\s*(.+)$') { $doc = $Matches[1].Trim() }
        elseif ($l -match '^Versi.n:\s*(.+)$')   { $ver = $Matches[1].Trim() }
        elseif ($l -match '^Vigencia:\s*(\d{4}-\d{2}-\d{2})\s*a\s*(\d{4}-\d{2}-\d{2})') {
            $desde = $Matches[1]; $hasta = $Matches[2]
        }
        elseif ($l -match '^(\d+(\.\d+)+)\s+(.+)$') {
            if ($actual) { $entradas += $actual }
            $actual = [ordered]@{
                documento = $doc; version = $ver; seccion = $Matches[1]; titulo = $Matches[3].Trim()
                texto = ''; vigencia_desde = $desde; vigencia_hasta = $hasta
            }
        }
        elseif ($actual -and $l.Trim()) {
            $actual.texto = ($actual.texto + ' ' + $l.Trim()).Trim()
        }
    }
    if ($actual) { $entradas += $actual }
}

$objs = @($entradas | ForEach-Object { [pscustomobject]$_ })
$sinExc = @($objs | Where-Object { $_.seccion -ne '4.2' })

[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'indice.json'), (ConvertTo-Json -InputObject $objs -Depth 3), $bom)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'indice-sin-excepcion.json'), (ConvertTo-Json -InputObject $sinExc -Depth 3), $bom)
Write-Host ("indice.json: {0} secciones | indice-sin-excepcion.json: {1} secciones" -f $objs.Count, $sinExc.Count)
