# Herramienta: consulta la bitácora de un incidente y devuelve datos estructurados (JSON).
# No recomienda nada: solo entrega datos para que se decida después.
# Compatible con PowerShell 5.1.
param(
    [Parameter(Mandatory)][string]$Incidente,
    [string]$Ruta = (Join-Path $PSScriptRoot 'bitacora.csv')
)

$id    = $Incidente.Trim()
$filas = @(Import-Csv -Path $Ruta -Encoding UTF8 | Where-Object { $_.incidente.Trim() -eq $id })

# Entidades distintas: sin espacios, sin distinguir mayúsculas. @() garantiza lista aunque haya una sola.
$entidades = @($filas | ForEach-Object { $_.entidad.Trim() } | Where-Object { $_ } | Sort-Object -Unique)

# Primer reporte: la hora más temprana (se interpreta como hora para ordenar bien).
$primer = $null
if ($filas.Count -gt 0) {
    $horas = @($filas | ForEach-Object {
        $t = $_.hora.Trim()
        $d = [datetime]::MinValue
        if ([datetime]::TryParse($t, [Globalization.CultureInfo]::InvariantCulture,
                                 [Globalization.DateTimeStyles]::None, [ref]$d)) { $d }
    } | Sort-Object)
    if ($horas.Count -gt 0) { $primer = $horas[0].ToString('HH:mm') }
}

$resultado = [ordered]@{
    incidente          = $id
    reportes           = $filas.Count
    entidadesDistintas = [string[]]$entidades
    primerReporte      = $primer
}

# Forzar que entidadesDistintas sea siempre arreglo JSON (PS 5.1 aplana listas de 1 elemento)
$json = ConvertTo-Json -InputObject ([pscustomobject]$resultado) -Depth 3 -Compress
$json
