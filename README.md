# vibesigns.nvim

Marks lines co-authored by LLM agents in the `gitsigns.nvim` signcolumn, so you can always eyeball the code that -- chances are -- was never read by a single living mortal soul.
I mean seriously, do people even interact with raw code in the industry anymore? This is a cry for help.

A line is considered LLM-written if its `git blame` shows that either the author or one of co-authors of the commit is among configured e-mail addresses.

Yes, this plugin was also vibe-coded, and within like an hour while I was showering, too. Boo-o-o.

## Requirements

- Neovim 0.10+
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) — used as the
  signcolumn host and as the `User GitSignsUpdate` update trigger. This
  plugin renders its own extmarks at a lower sign priority than gitsigns, so
  gitsigns' own signs always take visual precedence.
- `git` on `$PATH`

## Install (lazy.nvim)

```lua
{
  'theammir/vibesigns.nvim',
  dependencies = { 'lewis6991/gitsigns.nvim' },
  opts = {}
}
```

## Setup / options

```lua
require('vibesigns').setup({
  enabled = true,
  sign_text = '┃',
  debounce_ms = 150,
  priority = 3, -- below gitsigns sign_priority (6)
  color = '#9c6a2f', -- dim orange
  -- Each entry is a plain string (exact match) or a table:
  -- { 'exact', '<email>' } or { 'domain', '<domain>' }.
  agent_emails = {
    'noreply@anthropic.com', -- Claude / Claude Code
    'noreply@openai.com', -- Codex / ChatGPT
    'cursoragent@cursor.com', -- Cursor
    'devin@devin.ai', -- Devin
    '198982749+Copilot@users.noreply.github.com', -- GitHub Copilot agent
  },
})
```

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `true` | Master on/off switch. When `false`, `setup()` does nothing further (no autocmds, no highlight). |
| `sign_text` | string | `'┃'` | Text placed in the signcolumn for flagged lines. |
| `debounce_ms` | number | `150` | Delay before re-computing signs after a buffer event, coalescing bursts of `BufReadPost` / `BufWritePost` / `User GitSignsUpdate`. |
| `priority` | number | `3` | Sign extmark priority. Kept below gitsigns' own sign priority (`6`) so gitsigns' add/change/delete marks always win the signcolumn slot. |
| `color` | string | `'#9c6a2f'` | Foreground color (hex) used to define the `VibeSignsDim` highlight group. |
| `agent_emails` | (string / table)[] | see above | Addresses recognized as AI agents. Each entry carries its own match mode — see below. |

### `agent_emails` entries

Each element in the `agent_emails` table is either:

- `string` — matched exactly (case-insensitively) against the
  blame/co-author email.
  ```lua
  'noreply@anthropic.com'
  ```
- `{ mode, value }`:
  ```lua
  { 'exact',  'noreply@anthropic.com' } -- same as the bare string form
  { 'domain', 'devin.ai' }              -- flags every address @devin.ai
  ```

## Highlight group

`VibeSignsDim` controls the sign's color. It is defined
automatically on `setup()` and redefined on every `ColorScheme` event using
`color`. To theme it yourself, either set `color` in `opts` or override the
highlight group after setup:

```lua
vim.api.nvim_set_hl(0, 'VibeSignsDim', { fg = '#9c6a2f' })

```
