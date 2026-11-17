# Registra una decisión en registro-decisiones.csv (UTF-8 con BOM)
param(
    [Parameter(Mandatory)][string]$Incidente,
    [Parameter(Mandatory)][ValidateSet('Decisión del agente', 'Regla programada')][string]$Tipo,
    [Parameter(Mandatory)][string]$Decision,
    [Parameter(Mandatory)][string]$Razon,
    [string]$DatoEsperado = ''
)

$ruta = Join-Path $PSScriptRoot 'registro-decisiones.csv'

$fila = [pscustomobject]@{
    Fecha        = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Incidente    = $Incidente
    Tipo         = $Tipo
    Decision     = $Decision
    Razon        = $Razon
    DatoEsperado = $DatoEsperado
}

$filas = @()
if (Test-Path $ruta) { $filas = @(Import-Csv -Path $ruta -Encoding UTF8) }
$filas += $fila

# Export-Csv -Encoding UTF8 en PowerShell 5.1 escribe con BOM
$filas | Export-Csv -Path $ruta -NoTypeInformation -Encoding UTF8
Write-Host ("Registrado [{0}] {1}: {2}" -f $Tipo, $Incidente, $Decision)
