# AI Stack del equipo (OpenCode V2)

Stack compartido para trabajar con el mismo entorno de IA: orquestador + workers
económicos, memoria de código por grafo, skills de ahorro de tokens y MCP de GitHub.

## Qué incluye

| Pieza | Qué es |
|---|---|
| `agents/` (8) | `orchestrator` (primary) + `planner`, `coder`, `tester`, `reviewer`, `explorer`, `researcher`, `helper` (subagents). Todos con `opencode/muse-spark-1.3-contributor-free` (tier gratuito) |
| `scripts/setup.sh` | Instalador completo del stack |
| `scripts/github-mcp-server-wrapper.sh` | Auth de GitHub vía `gh`, sin secretos en disco |
| `PROMPT.md` | Prompt listo para pegarle a la IA y que instale todo |

Herramientas que instala el script:

- **codebase-memory-mcp** — grafo de conocimiento del repo (búsquedas estructurales, ~99% menos tokens que grep). Indexa el proyecto y lo mantiene con watcher.
- **caveman** — skills de respuesta tersa + proxy/MCP de compresión (`caveman_compress`, TOON).
- **agent-skills (addyosmani)** — 25 workflows de ingeniería (spec, TDD, review, debugging...).
- **github-mcp-server (oficial)** — repos, issues y PRs desde el agente (toolsets limitados para ahorrar contexto).

## Requisitos previos (cada máquina)

1. Arch/CachyOS con `yay` o `paru`, `npm`, `python3`, OpenCode V2.
2. `gh auth login` (el MCP de GitHub reusa ese login).
3. Cuenta de OpenCode (el tier gratuito basta: todos los agentes usan modelos `-free`).

## Instalación

```bash
git clone <URL-DE-ESTE-REPO> ai-stack
cd ai-stack
./scripts/setup.sh /ruta/a/tu/proyecto   # la ruta es opcional
```

El script es idempotente: se puede correr de nuevo para reparar/actualizar.
Al final muestra `opencode mcp list` (los 3 deben salir `connected`).
Reinicia tus sesiones de OpenCode para cargar todo.

## Uso diario

- Abre `opencode` en tu proyecto: arranca el `orchestrator`.
- Tareas simples: `Tab` para cambiar a `build`.
- Workers directos: `@coder ...`, `@reviewer ...`, etc.
- En la primera sesión del proyecto el grafo ya está indexado (`Cinnamon`, o el que pasaste al setup).

## Notas

- Los modelos están en `agents/*.md` (campo `model:`). El repo usa el tier gratuito
  (`muse-spark-1.3-contributor-free` en los 8); si tu equipo tiene Go, cámbialos ahí.
- `codebase-memory-mcp install` también configura otros clientes detectados (Claude Code, Codex, VS Code) si existen: es benigno.
- Nunca se commitean tokens: GitHub usa `gh auth token` en vivo.
