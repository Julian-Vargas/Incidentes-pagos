# Herramienta RAG: recupera secciones de procedimiento vigentes y pertinentes. No recomienda nada.
# Compatible con PowerShell 5.1.
param(
    [Parameter(Mandatory)][string]$Fecha,       # yyyy-MM-dd
    [Parameter(Mandatory)][string]$Consulta,
    [string]$Indice = (Join-Path $PSScriptRoot 'indice.json'),
    [switch]$IncluirRelacionadas
)

function ConvertTo-Normalizado([string]$s) {
    # minúsculas y sin tildes
    $d = $s.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($c in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
    }
    $sb.ToString()
}

$vacias = 'a','al','con','de','del','el','en','es','la','las','lo','los','o','para','por','que','se','si','su','un','una','y'
function Get-Palabras([string]$s) {
    @((ConvertTo-Normalizado $s) -split '[^a-z0-9\.]+' | Where-Object { $_ -and ($vacias -notcontains $_) } | Select-Object -Unique)
}

$f = [datetime]::ParseExact($Fecha, 'yyyy-MM-dd', $null)
# En PS 5.1 ConvertFrom-Json emite el arreglo como UN objeto: asignar primero y luego envolver
$todas = Get-Content $Indice -Encoding UTF8 -Raw | ConvertFrom-Json
$todas = @($todas)

# 1) Filtrar por vigencia ANTES de buscar
$vigentes = @($todas | Where-Object {
    $f -ge [datetime]::ParseExact($_.vigencia_desde, 'yyyy-MM-dd', $null) -and
    $f -le [datetime]::ParseExact($_.vigencia_hasta, 'yyyy-MM-dd', $null)
})

# 2) Coincidencia de palabras clave (sin mayúsculas ni tildes)
$claves = Get-Palabras $Consulta
$resultados = New-Object System.Collections.ArrayList
foreach ($s in $vigentes) {
    $palabrasSec = Get-Palabras ("$($s.titulo) $($s.texto)")
    $coinciden = @($claves | Where-Object { $palabrasSec -contains $_ })
    if ($coinciden.Count -gt 0) {
        [void]$resultados.Add([pscustomobject]@{ seccion = $s; puntaje = $coinciden.Count; motivo = 'coincidencia'; palabras = $coinciden })
    }
}

# 3) Relacionadas: excepciones del mismo documento y versión
if ($IncluirRelacionadas) {
    $base = @($resultados | ForEach-Object { "$($_.seccion.documento)|$($_.seccion.version)" } | Select-Object -Unique)
    foreach ($s in $vigentes) {
        $yaEsta = @($resultados | Where-Object { $_.seccion -eq $s }).Count -gt 0
        $esExc  = (ConvertTo-Normalizado $s.titulo) -match 'excepcion'
        if (-not $yaEsta -and $esExc -and ($base -contains "$($s.documento)|$($s.version)")) {
            [void]$resultados.Add([pscustomobject]@{ seccion = $s; puntaje = 0; motivo = 'relacionada (excepción)'; palabras = @() })
        }
    }
}

$salida = [ordered]@{
    fecha          = $Fecha
    consulta       = $Consulta
    indice         = (Split-Path $Indice -Leaf)
    seccionesVigentes = $vigentes.Count
    resultados     = @($resultados | Sort-Object @{e='puntaje';Descending=$true}, @{e={$_.seccion.seccion}} | ForEach-Object {
        [pscustomobject][ordered]@{
            referencia = [pscustomobject][ordered]@{ documento = $_.seccion.documento; version = $_.seccion.version; seccion = $_.seccion.seccion }
            titulo     = $_.seccion.titulo
            texto      = $_.seccion.texto
            motivo     = $_.motivo
            puntaje    = $_.puntaje
            palabras   = [string[]]@($_.palabras)
        }
    })
}
ConvertTo-Json -InputObject ([pscustomobject]$salida) -Depth 5
