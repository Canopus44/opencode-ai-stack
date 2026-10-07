# Prompt para la IA: instalar el AI Stack del equipo

Pega esto en tu agente (OpenCode u otro) en una máquina con Arch/CachyOS,
`yay`/`paru`, `npm`, `python3` y OpenCode V2 ya instalados:

---

Quiero el AI Stack del equipo. Haz esto paso a paso y reporta cada resultado:

1. Clona el repo del stack a `~/Proyectos/ai-stack` (URL: `https://github.com/Canopus44/opencode-ai-stack.git`).
2. Verifica requisitos: `yay` o `paru`, `npm`, `python3`, `opencode --version` (debe ser V2).
   Si falta algo, instálalo o dime exactamente qué instalar.
3. Verifica login GitHub con `gh auth status`. Si no hay sesión, detente y pídeme
   hacer `gh auth login` antes de seguir.
4. Ejecuta `~/Proyectos/ai-stack/scripts/setup.sh /ruta/a/mi/proyecto`
   (usa mi proyecto real; si el script pide contraseña sudo, pídemela).
   Si algún paso falla, no sigas a ciegas: muéstrame el error y propón la corrección.
5. Verifica al final:
   - `opencode mcp list` muestra `caveman`, `codebase-memory-mcp` y `github` en `connected`.
   - `ls ~/.config/opencode/agents/` incluye orchestrator, planner, coder, tester,
     reviewer, explorer, researcher y helper.
   - `ls ~/.config/opencode/skills/` tiene decenas de skills (caveman, TDD, review...).
   - El proyecto quedó indexado (el setup lo muestra en su salida).
6. Dame un resumen final: qué quedó instalado, qué cambió en mi config
   (con respaldo previo si tocaste `~/.config/opencode`) y qué debo reiniciar.

Restricciones: no guardes ningún token o secreto en archivos; la autenticación
de GitHub debe reusar `gh auth login`. No habilites arranques automáticos de
servicios; todo bajo demanda.
