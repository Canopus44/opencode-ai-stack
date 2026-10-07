<#Requires -Version 5.1>
<#
.SYNOPSIS
  Instala el stack de IA del equipo en OpenCode V2 (Windows 11).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 C:\ruta\a\tu\proyecto
#>
[CmdletBinding()]
param([string]$ProjectPath = "")

$ErrorActionPreference = "Stop"
function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# 0. Winget + herramientas base ----------------------------------------------
Get-Command winget -ErrorAction SilentlyContinue | Out-Null
if (-not $?) { Die "se requiere winget (viene con Windows 11 actualizado)" }
function Ensure-Winget($id) {
  $found = winget list --id $id --exact 2>$null | Select-String $id
  if (-not $found) { Info "instalando $id"; winget install --exact --id $id --silent --accept-source-agreements --accept-package-agreements }
  else { Info "$id ya instalado" }
}
Ensure-Winget "Git.Git"
Ensure-Winget "GitHub.cli"
Ensure-Winget "OpenJS.NodeJS.LTS"
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. GitHub auth ---------------------------------------------------------------
Get-Command gh -ErrorAction SilentlyContinue | Out-Null
if (-not $?) { Die "gh no quedó en PATH; abre una nueva terminal y reintenta" }
gh auth status 2>$null | Out-Null
if (-not $?) { Die "ejecuta primero: gh auth login" }

# 2. codebase-memory-mcp (auto-configura opencode) -------------------------------
if (-not (Get-Command codebase-memory-mcp -ErrorAction SilentlyContinue)) {
  Info "instalando codebase-memory-mcp (install.ps1 oficial)"
  $tmp = Join-Path $env:TEMP "cbm-install"
  New-Item -ItemType Directory -Force $tmp | Out-Null
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.ps1" -OutFile (Join-Path $tmp "install.ps1")
  Unblock-File (Join-Path $tmp "install.ps1")
  & (Join-Path $tmp "install.ps1")
}
codebase-memory-mcp config set auto_index true

# 3. Directorio de config de opencode -------------------------------------------
$ocDir = $null
foreach ($cand in @("$HOME/.config/opencode", "$env:APPDATA/opencode")) {
  if (Test-Path (Join-Path $cand "opencode.jsonc")) { $ocDir = $cand; break }
}
if (-not $ocDir) { $ocDir = "$HOME/.config/opencode"; New-Item -ItemType Directory -Force $ocDir | Out-Null }
Info "config opencode: $ocDir"

# 4. caveman (skills + proxy + MCP + plugin) --------------------------------------
npm install -g @caveman-ai/cli
$env:DO_NOT_TRACK = "1"
caveman telemetry off
caveman setup --install
caveman tools mcp install opencode

# 5. Skills (caveman + addyosmani) ------------------------------------------------
npx -y skills add JuliusBrussee/caveman -g
npx -y skills add addyosmani/agent-skills -g
$skillsDst = Join-Path $ocDir "skills"
New-Item -ItemType Directory -Force $skillsDst | Out-Null
$linked = 0
foreach ($src in @("$HOME/.agents/skills", "$env:USERPROFILE/.agents/skills") | Select-Object -Unique) {
  if (-not (Test-Path $src)) { continue }
  Get-ChildItem -Directory $src | ForEach-Object {
    if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
      $dst = Join-Path $skillsDst $_.Name
      if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
      Copy-Item -Recurse -Force $_.FullName $dst
      $linked++
    }
  }
}
Info "skills copiadas: $linked"

# 6. Agentes del equipo ------------------------------------------------------------
$agentsDst = Join-Path $ocDir "agents"
New-Item -ItemType Directory -Force $agentsDst | Out-Null
Copy-Item -Force (Join-Path $ScriptDir "..\agents\*.md") $agentsDst
Info "agentes copiados"

# 7. github-mcp-server (binario oficial + wrapper con token vía gh) ----------------
$binDir = "$HOME/.local/bin"
New-Item -ItemType Directory -Force $binDir | Out-Null
$exe = Join-Path $binDir "github-mcp-server.exe"
if (-not (Test-Path $exe)) {
  Info "descargando github-mcp-server (Windows x86_64)"
  $dl = Join-Path $env:TEMP "github-mcp-server-dl"
  New-Item -ItemType Directory -Force $dl | Out-Null
  Push-Location $dl
  gh release download --repo github/github-mcp-server --pattern "github-mcp-server_Windows_x86_64.zip" --pattern "github-mcp-server_*_checksums.txt"
  $zip = Get-ChildItem "github-mcp-server_Windows_x86_64.zip" | Select-Object -First 1
  $sums = Get-ChildItem "*_checksums.txt" | Select-Object -First 1
  if ($sums) {
    $want = (Select-String -Pattern ([regex]::Escape($zip.Name) + "$") $sums.FullName | ForEach-Object { $_.Line.Split()[0] })
    $got = (Get-FileHash $zip.FullName -Algorithm SHA256).Hash.ToLower()
    if ($want -and ($want.ToLower() -ne $got)) { Die "checksum del zip no coincide" }
    Info "checksum OK"
  }
  Expand-Archive -Force $zip.FullName $dl
  $found = Get-ChildItem -Recurse -Filter "github-mcp-server.exe" $dl | Select-Object -First 1
  if (-not $found) { Die "no se encontró el exe en el zip" }
  Copy-Item $found.FullName $exe
  Pop-Location
}
Copy-Item -Force (Join-Path $ScriptDir "github-mcp-server-wrapper.ps1") (Join-Path $binDir "github-mcp-server-wrapper.ps1")

# 8. opencode.jsonc: default_agent + 3 MCP (preserva el resto) -----------------------
$jsonc = Join-Path $ocDir "opencode.jsonc"
if (Test-Path $jsonc) { $cfg = Get-Content $jsonc -Raw | ConvertFrom-Json }
else { $cfg = [pscustomobject]@{ '$schema' = "https://opencode.ai/config.json" } }
if (-not $cfg.'$schema') { $cfg | Add-Member -NotePropertyName '$schema' -NotePropertyValue "https://opencode.ai/config.json" }
$cfg.default_agent = "orchestrator"
if (-not $cfg.mcp) { $cfg | Add-Member -NotePropertyName mcp -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.mcp.servers) { $cfg.mcp | Add-Member -NotePropertyName servers -NotePropertyValue ([pscustomobject]@{}) }
$shell = (Get-Command pwsh -ErrorAction SilentlyContinue) ? "pwsh" : "powershell"
$servers = $cfg.mcp.servers
$servers | Add-Member -NotePropertyName "codebase-memory-mcp" -NotePropertyValue ([pscustomobject]@{ type = "local"; command = @("$binDir/codebase-memory-mcp.exe") }) -Force
$servers | Add-Member -NotePropertyName "caveman" -NotePropertyValue ([pscustomobject]@{ type = "local"; command = @("$HOME/.caveman/bin/caveman-mcp.exe") }) -Force
$servers | Add-Member -NotePropertyName "github" -NotePropertyValue ([pscustomobject]@{ type = "local"; command = @($shell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "$binDir/github-mcp-server-wrapper.ps1") }) -Force
($cfg | ConvertTo-Json -Depth 10) | Set-Content -Encoding UTF8 $jsonc
Info "opencode.jsonc actualizado"

# 9. Index del proyecto (opcional) ------------------------------------------------------
if ($ProjectPath -ne "") {
  if (-not (Test-Path $ProjectPath)) { Die "no existe $ProjectPath" }
  Info "indexando $ProjectPath"
  $name = Split-Path -Leaf $ProjectPath
  codebase-memory-mcp cli --progress index_repository --repo-path $ProjectPath --name $name
}

# 10. Verificación -----------------------------------------------------------------------
Info "verificando MCP..."
opencode mcp list
Write-Host ""
Write-Host "Listo. Reinicia tus sesiones de OpenCode para cargar MCP + skills + agentes."
