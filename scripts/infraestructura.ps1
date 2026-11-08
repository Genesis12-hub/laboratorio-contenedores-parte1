# Ejercicio manual completado para Linux o Windows con Docker.
# El script visto en clase solo ejecutaba las dos descargas y el listado de
# imágenes. Los apartados de volúmenes, contenedores, validación y estado
# estaban como comentarios vacíos. Aquí esos apartados sí hacen el trabajo.
# No es una transcripción literal del archivo del docente.
#
# Recuperación exigida: borrar el contenedor y crear otro con el mismo volumen.
# La copia .backup_redis de un Redis en marcha solo se lista; no se presenta
# como respaldo consistente. -VerificacionExtraRespaldo hace una prueba aparte,
# con el servidor detenido y un volumen vacío.

#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$BindAddress = '127.0.0.1',
    [int]$RedisPort = 6379,
    [string]$VolumeName = 'vol_redis_datos',
    [string]$ContainerName = 'infra-redis',
    [string]$RecoveredName = 'infra-redis-recuperado',
    [string]$SampleKey = 'lab1:muestra',
    [string]$SampleValue = 'persistencia-volumen-local',
    [string]$BackupDir = './.backup_redis',
    [switch]$VerificacionExtraRespaldo
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$script:UseSudo = $false
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    & sudo -n docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker no responde ni con el usuario actual ni con sudo.'
    }
    $script:UseSudo = $true
}

function Invoke-Docker {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DockerArgs,
        [switch]$AllowFailure
    )
    if ($script:UseSudo) {
        & sudo -n docker @DockerArgs
    }
    else {
        & docker @DockerArgs
    }
    if (-not $AllowFailure -and $LASTEXITCODE -ne 0) {
        throw "docker terminó con código ${LASTEXITCODE}: docker $($DockerArgs -join ' ')"
    }
}

function Remove-LocalTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) {
        return
    }
    if ($script:UseSudo) {
        & sudo -n rm -rf -- $Path
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo borrar $Path."
        }
    }
    else {
        Remove-Item -Recurse -Force $Path
    }
}

function Remove-NamedContainer {
    param([Parameter(Mandatory = $true)][string]$Name)
    $found = Invoke-Docker -DockerArgs @('ps', '-aq', '--filter', ('name=^/{0}$' -f $Name)) -AllowFailure
    if ($found) {
        Invoke-Docker -DockerArgs @('rm', '-f', $Name)
    }
}

Write-Host '== Descargas =='
Invoke-Docker -DockerArgs @('pull', 'redis:7-alpine')
Invoke-Docker -DockerArgs @('pull', 'postgres:16-alpine')

Write-Host '== Imágenes =='
Invoke-Docker -DockerArgs @('images', '--format', 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}')

Write-Host '== volumenes =='
Invoke-Docker -DockerArgs @('volume', 'create', $VolumeName)
Invoke-Docker -DockerArgs @('volume', 'inspect', $VolumeName)
Invoke-Docker -DockerArgs @('volume', 'ls', '--filter', ('name={0}' -f $VolumeName))

Write-Host '== eliminacion y ejecucion de contenedores =='
Write-Host "Publicación local: ${BindAddress}:${RedisPort}->6379. No se abre el puerto en otras interfaces."
Remove-NamedContainer -Name $ContainerName
Remove-NamedContainer -Name $RecoveredName
Invoke-Docker -DockerArgs @(
    'run', '-d',
    '--name', $ContainerName,
    '-p', "${BindAddress}:${RedisPort}:6379",
    '-v', "${VolumeName}:/data",
    '--restart', 'unless-stopped',
    'redis:7-alpine',
    'redis-server', '--appendonly', 'yes'
)

$ready = $false
foreach ($attempt in 1..20) {
    Invoke-Docker -DockerArgs @('exec', $ContainerName, 'redis-cli', 'PING') -AllowFailure | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    throw "Redis no respondió en $ContainerName."
}

Write-Host '== Validacion de conectividad a la red y persistencia de datos (Exec) =='
Invoke-Docker -DockerArgs @('exec', $ContainerName, 'redis-cli', 'PING')
Invoke-Docker -DockerArgs @('exec', $ContainerName, 'redis-cli', 'SET', $SampleKey, $SampleValue)
$readBack = (Invoke-Docker -DockerArgs @('exec', $ContainerName, 'redis-cli', 'GET', $SampleKey) | Out-String).Trim()
Write-Host "GET $SampleKey=$readBack"
if ($readBack -ne $SampleValue) {
    throw "GET devolvió '$readBack' y se esperaba '$SampleValue'."
}
Invoke-Docker -DockerArgs @('exec', $ContainerName, 'redis-cli', 'SAVE')

Write-Host 'AVISO: la copia siguiente se toma con Redis en marcha. Lista archivos; no demuestra un respaldo consistente.'
Write-Host 'La recuperación de este ejercicio reutiliza el mismo volumen. No restaura esta copia sobre un volumen vacío.'
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
Invoke-Docker -DockerArgs @('cp', "${ContainerName}:/data/appendonlydir/", $BackupDir)
if ($script:UseSudo) {
    $owner = if ([string]::IsNullOrWhiteSpace($env:USER)) { 'ubuntu' } else { $env:USER }
    & sudo -n chown -R "${owner}:${owner}" $BackupDir
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo ajustar el propietario de la copia local.'
    }
}
Write-Host '== Archivos copiados =='
Get-ChildItem -Force -Recurse -File $BackupDir | ForEach-Object { '{0} {1}' -f $_.Length, $_.FullName }

Write-Host '== Recuperación por el mismo volumen =='
Invoke-Docker -DockerArgs @('rm', '-f', $ContainerName)
Invoke-Docker -DockerArgs @(
    'run', '-d',
    '--name', $RecoveredName,
    '-p', "${BindAddress}:${RedisPort}:6379",
    '-v', "${VolumeName}:/data",
    '--restart', 'unless-stopped',
    'redis:7-alpine',
    'redis-server', '--appendonly', 'yes'
)
$ready = $false
foreach ($attempt in 1..20) {
    Invoke-Docker -DockerArgs @('exec', $RecoveredName, 'redis-cli', 'PING') -AllowFailure | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    throw "Redis no respondió en $RecoveredName."
}
$recovered = (Invoke-Docker -DockerArgs @('exec', $RecoveredName, 'redis-cli', 'GET', $SampleKey) | Out-String).Trim()
if ($recovered -ne $SampleValue) {
    throw "Tras recrear el contenedor con el mismo volumen, GET devolvió '$recovered'."
}
Write-Host "CLAVE_RECUPERADA $SampleKey=$recovered"

if ($VerificacionExtraRespaldo) {
    Write-Host '== VERIFICACIÓN EXTRA: copia en reposo hacia un volumen vacío =='
    Write-Host 'Esta prueba no sustituye la recuperación por el mismo volumen.'
    Invoke-Docker -DockerArgs @('stop', $RecoveredName)
    $quiesced = Join-Path ([System.IO.Path]::GetTempPath()) 'lab1-appendonly-reposo'
    Remove-LocalTree -Path $quiesced
    New-Item -ItemType Directory -Force -Path $quiesced | Out-Null
    Invoke-Docker -DockerArgs @('cp', "${RecoveredName}:/data/appendonlydir", $quiesced)
    $extraVolume = 'vol_redis_extra_verificacion'
    $extraContainer = 'infra-redis-extra-verificacion'
    $extraPort = 16379
    try {
        Remove-NamedContainer -Name $extraContainer
        $presentVolumes = @(Invoke-Docker -DockerArgs @('volume', 'ls', '-q'))
        if ($presentVolumes -contains $extraVolume) {
            Invoke-Docker -DockerArgs @('volume', 'rm', $extraVolume)
        }
        Invoke-Docker -DockerArgs @('volume', 'create', $extraVolume)
        $source = Join-Path $quiesced 'appendonlydir'
        Invoke-Docker -DockerArgs @(
            'run', '--rm',
            '-v', "${extraVolume}:/data",
            '-v', "${source}:/backup:ro",
            'redis:7-alpine',
            'sh', '-c', 'mkdir -p /data/appendonlydir && cp -a /backup/. /data/appendonlydir && chown -R redis:redis /data'
        )
        Invoke-Docker -DockerArgs @(
            'run', '-d',
            '--name', $extraContainer,
            '--restart', 'no',
            '-p', "127.0.0.1:${extraPort}:6379",
            '-v', "${extraVolume}:/data",
            'redis:7-alpine',
            'redis-server', '--appendonly', 'yes'
        )
        $extraReady = $false
        foreach ($attempt in 1..20) {
            Invoke-Docker -DockerArgs @('exec', $extraContainer, 'redis-cli', 'PING') -AllowFailure | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $extraReady = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        if (-not $extraReady) {
            throw 'La verificación extra no obtuvo PING.'
        }
        $extraValue = (Invoke-Docker -DockerArgs @('exec', $extraContainer, 'redis-cli', 'GET', $SampleKey) | Out-String).Trim()
        if ($extraValue -ne $SampleValue) {
            throw "La verificación extra leyó '$extraValue'."
        }
        Write-Host "EXTRA_RESPALDO_OK $SampleKey=$extraValue puerto=$extraPort"
    }
    finally {
        Remove-NamedContainer -Name $extraContainer
        $presentVolumes = @(Invoke-Docker -DockerArgs @('volume', 'ls', '-q') -AllowFailure)
        if ($presentVolumes -contains $extraVolume) {
            Invoke-Docker -DockerArgs @('volume', 'rm', $extraVolume)
        }
        Remove-LocalTree -Path $quiesced
    }
    Invoke-Docker -DockerArgs @('start', $RecoveredName)
}

Write-Host '== Estado de los contenedores activos =='
Invoke-Docker -DockerArgs @('ps', '--format', 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}')
Invoke-Docker -DockerArgs @('logs', '--tail', '20', $RecoveredName)
Write-Host 'EJERCICIO_MANUAL_OK'
