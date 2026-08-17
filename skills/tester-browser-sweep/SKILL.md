---
name: tester-browser-sweep
description: Use when running the Tester role on a UI-affecting ticket. Drives a deterministic browser sweep — functional matrix + console/network capture + axe-core a11y — through the `mcp__claude-in-chrome__*` driver.
---

# Tester browser sweep

Driver-agnostic playbook: the pass list below is the contract; the
invocation primitives at the end are one way to satisfy it.

## Pass list

For each route in scope (taken from the ticket's plan note):

1. **Functional matrix** — exercise every interaction listed in the
   ticket's AC (click paths, form submits, keyboard flows, error states).
   Capture screenshots at each step.

2. **Console + network capture** — enable verbose logging before
   navigation. Collect:
   - Console errors / warnings (non-error logs allowed).
   - Network 4xx / 5xx.
   - Uncaught promise rejections.

3. **Axe-core a11y sweep** — inject axe via the driver's `evaluate`
   primitive and run `axe.run()`. Capture all `violations` with their
   `impact` and the `target` selectors.

4. **Theme matrix** — if the project ships multiple themes (light/dark
   etc.), repeat passes 1-3 in each theme. Theme cascade bugs are a
   common Tester-only signal.

## Severity mapping

- `BLOCKER` — functional flow broken; AC unmet; axe `critical` impact.
- `MAJOR`   — functional regression in adjacent flow; axe `serious`.
- `MINOR`   — axe `moderate`; console warning indicating real issue.
- `NIT`     — axe `minor`; visual polish.

## Output

One finding per line:

```
<route>:<selector>: <severity>: <problem>. <fix-or-evidence>.
```

End with a verdict: `PASS` or `FAIL`.

## Driver: `claude-in-chrome` MCP

- Navigate: `mcp__claude-in-chrome__navigate { url: "<route>" }`
- Inject axe: `mcp__claude-in-chrome__evaluate { script: "<axe-injection-js>" }`
- Console + network: use the MCP's log primitives.

Requires the Claude Code Chrome extension — launch with `claude --chrome`
or run `/chrome` mid-session. Without it the MCP tools are unreachable
and the sweep cannot run; report that rather than substituting a
static-analysis pass.

## axe-core injection snippet

```js
(async () => {
  const r = await fetch('https://unpkg.com/axe-core/axe.min.js').then(x => x.text());
  eval(r);
  const out = await axe.run();
  return out.violations;
})();
```

Cache locally per session if the driver supports it.
