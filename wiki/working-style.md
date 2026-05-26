# Working Style

## Communication Preferences

- **Concise responses preferred.** Short, direct answers with clear structure. No padding or narration.
- **Markdown formatting** — uses headers and tables; renders in monospace (Claude Code CLI/web).
- **Asks for plans before execution.** Uses plan mode; wants to review strategy before implementation starts.
- **Proactive wiki maintenance expected.** Wants Claude to read and update the wiki automatically each session without being prompted.

## Code Preferences

- **Single source of truth.** Engine logic lives in one file; other files source it. Never duplicate logic.
- **Pure functions.** Analysis functions are stateless and side-effect free. Runners and reports call them.
- **No unnecessary comments.** Code is self-documenting via naming. Comments only for non-obvious invariants or gotchas.
- **Strict data ingestion.** Validate field counts, handle missing tokens explicitly, never silently mis-parse.
- **Tidy output.** Use `broom` and tibbles; avoid base R list structures in outputs meant for reporting.

## Autonomy Level

- Prefers to review plans before implementation.
- Trusts Claude to explore and research independently.
- Wants confirmations before destructive or hard-to-reverse actions (force push, deletes, etc.).

## Known Dislikes

*(Claude appends as discovered)*
