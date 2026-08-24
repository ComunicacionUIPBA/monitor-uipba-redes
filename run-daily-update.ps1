$claude = "C:\Users\jpansowy\AppData\Local\Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\node-v24.15.0-win-x64\claude.cmd"
$repoDir = "C:\Users\jpansowy\projects\monitor-uipba-redes"
$logDir = Join-Path $repoDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("run-{0}.log" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
$lockFile = Join-Path $logDir "run.lock"

# Marca de arranque escrita YA, antes de cualquier otra cosa -- si el script
# revienta mas adelante, esto deja rastro de que al menos empezo a correr.
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Arrancando run-daily-update.ps1 (PID $PID)" | Out-File -FilePath $logFile -Encoding utf8

function Show-Alerta($mensaje, $titulo) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($mensaje, $titulo, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    } catch {
        # Si ni el cartel se puede mostrar, al menos ya quedo en el log.
    }
}

# Evita corridas superpuestas (ej. si ayer quedo una colgada y hoy arranca otra).
if (Test-Path $lockFile) {
    $lockAge = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    if ($lockAge.TotalHours -lt 2) {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Ya hay otra corrida en curso (lock de hace $([math]::Round($lockAge.TotalMinutes)) min). Salgo sin hacer nada." | Out-File -FilePath $logFile -Append -Encoding utf8
        exit 0
    } else {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Lock viejo (hace $([math]::Round($lockAge.TotalHours,1))h), lo piso y sigo." | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}
"$PID" | Out-File -FilePath $lockFile -Encoding utf8

try {
    Set-Location $repoDir

    $prompt = "/monitor-uipba-redes Corre la actualizacion diaria de hoy. Segui al pie de la letra las reglas de la skill, en especial: (1) Sector Industrial son SOLO cuentas/personas reales y verificables por red (X, LinkedIn, Instagram, Facebook), nunca noticias reformuladas como si fueran redes -- si no encontras una voz real en alguna red, dejala afuera y decilo, no la fuerces; el minimo de 1 por red es una meta, no una obligacion a cualquier costo. (2) CRITICO: en cada tarjeta de Sector Industrial, el title y el quote tienen que ser 100% sobre el TEMA real (tasas, credito, costos, cierres, etc.) -- CERO menciones a que existe una cuenta, a que es real/activa/verificada, o a quien la documenta; la persona/cuenta va UNICAMENTE en source.name. Antes de guardar cada tarjeta, tapate mentalmente el campo source y fijate si el quote todavia deja entender que hay una cuenta hablando de esto -- si es asi, esta mal escrito, reescribilo. (3) La Calle Bonaerense apunta a minimo 3 temas reales, sin necesidad de conexion industrial forzada. (4) No inventes datos, cuentas, ni citas. Al terminar, hace commit y push a GitHub, y dejá un resumen claro de que redes tuvieron voz real hoy y cuales quedaron afuera y por que."

    & $claude -p $prompt --allowed-tools "Bash Edit Read Write WebSearch WebFetch Skill Grep Glob" *>&1 | Tee-Object -FilePath $logFile -Append
    $exitCode = $LASTEXITCODE
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] claude termino con exit code $exitCode" | Out-File -FilePath $logFile -Append -Encoding utf8

    $logContent = Get-Content -Path $logFile -Raw -ErrorAction SilentlyContinue
    if ($logContent -match "OAuth access token has expired" -or $logContent -match "Failed to authenticate") {
        Show-Alerta "El Monitor UIPBA no se pudo actualizar hoy porque el login de Claude Code vencio.`n`nAbri una terminal y corre:  claude`n(y logueate de nuevo si te lo pide)`n`nDespues no hace falta nada mas, se arregla solo para las proximas corridas." "Monitor UIPBA: hace falta re-loguearse"
    } elseif ($exitCode -ne 0) {
        Show-Alerta "El Monitor UIPBA fallo hoy con un error inesperado (codigo $exitCode).`n`nRevisa el archivo:`n$logFile`n`nO pedile a Claude que lo revise en la proxima sesion." "Monitor UIPBA: fallo la corrida de hoy"
    }
}
catch {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] EXCEPCION EN POWERSHELL: $($_.Exception.Message)`n$($_.ScriptStackTrace)" | Out-File -FilePath $logFile -Append -Encoding utf8
    Show-Alerta "El Monitor UIPBA fallo hoy con un error de PowerShell.`n`nRevisa el archivo:`n$logFile" "Monitor UIPBA: fallo la corrida de hoy"
}
finally {
    Remove-Item -Path $lockFile -ErrorAction SilentlyContinue
}
