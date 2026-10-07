#!/usr/bin/env bash
# setup.sh — instala el stack de IA del equipo en OpenCode V2 (Arch/CachyOS).
# Uso: ./scripts/setup.sh [/ruta/al/proyecto-a-indexar]
#
# Instala: codebase-memory-mcp, caveman (skills+proxy+MCP), agent-skills,
# github-mcp-server, 8 agentes orquestados y 3 MCP registrados.
# Requiere: sudo (contraseña), sesión de GitHub vía `gh auth login`, OpenCode V2.
set -euo pipefail

REPO_PATH="${1:-}"
 die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

command -v pacman >/dev/null || die "se requiere una distro basada en Arch (pacman)"
AUR=""
if command -v yay >/dev/null; then AUR=yay
elif command -v paru >/dev/null; then AUR=paru
else die "instala yay o paru primero"
fi
command -v npm >/dev/null || die "instala nodejs/npm primero"
command -v python3 >/dev/null || die "instala python primero"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Binarios AUR -----------------------------------------------------------
install_aur() {
  local pkg="$1"
  pacman -Q "$pkg" >/dev/null 2>&1 && { info "$pkg ya instalado"; return; }
  info "instalando $pkg (compila, luego instala con sudo)"
  "$AUR" -S --noconfirm --needed "$pkg" || true
  local built
  built=$(ls ~/.cache/yay/"$pkg"/*.pkg.tar.zst 2>/dev/null | head -n 1)
  [ -n "$built" ] || die "no se generó el paquete $pkg"
  sudo pacman -U --noconfirm "$built"
}
install_aur codebase-memory-mcp-bin
install_aur github-mcp-server-bin

# 2. GitHub auth -------------------------------------------------------------
command -v gh >/dev/null || die "instala gh (GitHub CLI) primero"
gh auth status >/dev/null 2>&1 || die "ejecuta primero: gh auth login"

# 3. codebase-memory-mcp (auto-configura opencode) ----------------------------
CBM=/usr/bin/codebase-memory-mcp
[ -x "$CBM" ] || die "no se encontró codebase-memory-mcp"
# El instalador debe correr desde una ruta propia del usuario (no /usr/bin).
mkdir -p ~/.local/bin
cp -f "$CBM" ~/.local/bin/codebase-memory-mcp
~/.local/bin/codebase-memory-mcp install -y
~/.local/bin/codebase-memory-mcp config set auto_index true

# 4. caveman (skills + proxy + MCP + plugin) ----------------------------------
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
npm install -g @caveman-ai/cli
export DO_NOT_TRACK=1
caveman telemetry off || true
caveman setup --install
caveman tools mcp install opencode

# 5. Skills (caveman + addyosmani) --------------------------------------------
npx -y skills add JuliusBrussee/caveman -g || true
npx -y skills add addyosmani/agent-skills -g || true
mkdir -p ~/.config/opencode/skills
for d in ~/.agents/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  ln -sfn "$d" ~/.config/opencode/skills/"$(basename "$d")"
done
info "skills enlazadas: $(ls ~/.config/opencode/skills | wc -l)"

# 6. Agentes del equipo --------------------------------------------------------
mkdir -p ~/.config/opencode/agents
cp -f "$SCRIPT_DIR/../agents/"*.md ~/.config/opencode/agents/
info "agentes copiados"

# 7. Wrapper GitHub (token vía gh, nada en disco) ------------------------------
cp -f "$SCRIPT_DIR/github-mcp-server-wrapper.sh" ~/.local/bin/
chmod +x ~/.local/bin/github-mcp-server-wrapper.sh

# 8. opencode.jsonc: default_agent + 3 MCP (preserva el resto) ------------------
python3 - "$HOME" <<'EOF'
import json, sys
home = sys.argv[1]
p = f"{home}/.config/opencode/opencode.jsonc"
try:
    d = json.load(open(p))
except FileNotFoundError:
    d = {"$schema": "https://opencode.ai/config.json"}
d.setdefault("$schema", "https://opencode.ai/config.json")
d["default_agent"] = "orchestrator"
servers = d.setdefault("mcp", {}).setdefault("servers", {})
servers["codebase-memory-mcp"] = {"type": "local", "command": [f"{home}/.local/bin/codebase-memory-mcp"]}
servers["caveman"] = {"type": "local", "command": [f"{home}/.caveman/bin/caveman-mcp"]}
servers["github"] = {"type": "local", "command": [f"{home}/.local/bin/github-mcp-server-wrapper.sh"]}
json.dump(d, open(p, "w"), indent=2)
print("opencode.jsonc actualizado:", list(servers.keys()))
EOF

# 9. Index del proyecto (opcional) ----------------------------------------------
if [ -n "$REPO_PATH" ]; then
  [ -d "$REPO_PATH" ] || die "no existe $REPO_PATH"
  info "indexando $REPO_PATH"
  codebase-memory-mcp cli --progress index_repository --repo-path "$REPO_PATH" --name "$(basename "$REPO_PATH")"
fi

# 10. Verificación ---------------------------------------------------------------
info "verificando MCP..."
opencode mcp list || true
echo ""
echo "Listo. Reinicia tus sesiones de OpenCode para cargar MCP + skills + agentes."
