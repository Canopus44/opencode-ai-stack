# Wrapper MCP GitHub (Windows): usa el token del login `gh` existente, sin guardar secretos en disco.
$ErrorActionPreference = "Stop"
$token = (& gh auth token) | Select-Object -First 1
if (-not $token) { Write-Error "gh auth login requerido"; exit 1 }
$env:GITHUB_PERSONAL_ACCESS_TOKEN = $token.Trim()
$exe = Join-Path $HOME ".local/bin/github-mcp-server.exe"
& $exe stdio --toolsets context,repos,issues,pull_requests @args
