#!/usr/bin/env bash
# Wrapper MCP GitHub: usa el token del login `gh` existente, sin guardar secretos en disco.
set -euo pipefail
export GITHUB_PERSONAL_ACCESS_TOKEN="$("$HOME/.local/bin/gh" auth token)"
exec /usr/bin/github-mcp-server stdio --toolsets context,repos,issues,pull_requests "$@"
