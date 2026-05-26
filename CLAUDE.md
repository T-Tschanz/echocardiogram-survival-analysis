# CLAUDE.md — Personal Wiki Schema

This file defines how Claude reads and maintains the personal wiki in `wiki/`.
Follow these rules in every session, without being asked.

---

## Session Start Protocol

1. Read `wiki/index.md` to orient to the current state of the wiki.
2. Read `wiki/profile.md` and `wiki/working-style.md` once per session.
3. Read any project page relevant to the current task (e.g., `wiki/projects/echocardiogram.md`).
4. Do not narrate this process unless the user asks.

---

## Session End Protocol

When a session's main work is done, before signing off:

1. Append an entry to the **Recent Updates** log in `wiki/index.md`:
   ```
   - YYYY-MM-DD: <one sentence describing what was done or learned>
   ```
2. Update the relevant project page with any new decisions, findings, or open questions.
3. If any new methodological knowledge was surfaced, add it to the appropriate `wiki/methods/` page.
4. If the user shared personal context, append it to `wiki/profile.md`.
5. If the user expressed a preference or working-style signal, append it to `wiki/working-style.md`.

---

## Update Rules

- **Never delete content.** Revise or append only.
- **Flag contradictions** with a blockquote: `> ⚠ CONFLICT: <description>`
- **Date every new entry** in `YYYY-MM-DD` format.
- **Profile updates**: only update `wiki/profile.md` when the user explicitly shares personal context — do not infer or hallucinate.
- **Preference capture**: update `wiki/working-style.md` immediately when the user states a preference, even casually.

---

## Wiki File Map

| File | Purpose |
|------|---------|
| `wiki/index.md` | Master TOC + reverse-chronological update log |
| `wiki/profile.md` | User background, expertise, current projects |
| `wiki/working-style.md` | Communication and code preferences |
| `wiki/projects/echocardiogram.md` | Deep context on this project |
| `wiki/methods/survival-analysis.md` | Survival analysis methodology notes |
