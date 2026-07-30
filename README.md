<div align="center">
  <img width="520" alt="image" src="https://github.com/user-attachments/assets/bb4c5862-4a39-43af-a792-b8df60e686e4" />
  <h1><b>vibesigns.nvim</b></h1>
</div>

Marks lines co-authored by LLM agents in the `gitsigns.nvim` signcolumn, so you can always eyeball the code that -- chances are -- was never read by a single living mortal soul.
I mean seriously, do people even interact with raw code in the industry anymore? This is a cry for help.

> [!NOTE]
> The purpose of the tool is to flag code that is *potentially* unreviewed, unread or untrusted, being authored and immediately committed by an autonomous agent.
> There is no implication to flag simpler automation tools, since they act on behalf of codeowners, and usually don't introduce extra complexity into the codebase.
> That being said, there is no guarantee that detected code didn't receive human attention, even if commited by an agent; or that agents always attribute code authorship.

A line is considered LLM-written if it's unchanged in the working tree and one of the following is true:

- The line is authored, or co-authored, by one of the configured emails or users;
- The line's commit message, as shown by `git blame`, contains one of the configured attribute values (such as `Made-with: Cursor`);

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
  --
  -- Some of these were sourced from: mat-1/slopcheck on Github
  agent_emails = {
    -- PR review tools (optional, probably explicitly approved by ppl?)
    -- '165735046+greptile-apps[bot]@users.noreply.github.com', -- Greptile (PR review)
    -- '136622811+coderabbitai[bot]@users.noreply.github.com', -- CodeRabbit (PR review)
    -- '96075541+graphite-app[bot]@users.noreply.github.com', -- Graphite (PR review)
    'noreply@anthropic.com', -- Claude / Claude Code
    '41898282+claude[bot]@users.noreply.github.com',
    'noreply@openai.com', -- Codex / ChatGPT
    'codex@openai.com',
    'cursoragent@cursor.com', -- Cursor
    '199175422+chatgpt-codex-connector[bot]@users.noreply.github.com',
    'devin@devin.ai', -- Devin
    '158243242+devin-ai-integration[bot]@users.noreply.github.com',
    '198982749+Copilot@users.noreply.github.com', -- GitHub Copilot agents
    '175728472+Copilot@users.noreply.github.com',
    'copilot@github.com',
    'qwen-coder@alibabacloud.com', -- Qwen
    'noreply@z.ai', -- GLM
    'aider@aider.chat', -- Aider.ai
    'openhands@all-hands.dev', -- OpenHands
    '218195315+gemini-cli@users.noreply.github.com', -- Gemini
    '176961590+gemini-code-assist[bot]@users.noreply.github.com',
    '161369871+google-labs-jules[bot]@users.noreply.github.com', -- Google Jules
    '208079219+amazon-q-developer[bot]@users.noreply.github.com', -- Amazon Q
    '138933559+factory-droid[bot]@users.noreply.github.com', -- Factory.ai
    '240665456+kilo-code-bot[bot]@users.noreply.github.com', -- Kilo.ai
    'v0[bot]@users.noreply.github.com', -- Vercel v0
    'amp@ampcode.com', -- Amp
    'amp@sourcegraph.com',
    'junie@jetbrains.com>', -- JetBrains
    'agent@replit.com', -- Replit
    '189301087+windsurf-bot[bot]@users.noreply.github.com', -- Windsurf
    'assistant@zed.dev', -- Zed
    'agent@warp.dev', -- Warp
  },
  -- Arbitrary commit trailers. Key = trailer name (case-insensitive),
  -- value = Lua pattern or list of them, matched case-insensitively.
  agent_trailers = {
    ['Made-with'] = { 'Cursor' }, -- Cursor
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
| `agent_trailers` | table\<string, string / string[]> | `{ ['Made-with'] = { 'Cursor' } }` | Arbitrary commit trailers recognized as AI agents, keyed by trailer name. See below. |

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

`agent_emails` is checked against the blame author of a commit and against the
addresses in its `Co-authored-by:` trailers.

### `agent_trailers` entries

`agent_trailers` maps a commit trailer (attribute) name to
the [Lua pattern](https://www.lua.org/manual/5.1/manual.html#5.4.1) (or list of
patterns) its value must match:

```lua
agent_trailers = {
  ['Made-with'] = { 'Cursor', 'Aider' }, -- flags `Made-with: Cursor` or `: Aider`
  ['Generated-with'] = 'Copilot', -- a bare string works as a single pattern
  ['Agent-version'] = { '^claude%-%d+$' }, -- full Lua pattern syntax
}
```

- Trailer **names** are matched case-insensitively (a trailing `:` is tolerated).
- Trailer **values** are matched case-insensitively with `string.find`, so
  patterns are **unanchored**: `'Cursor'` also flags `Made-with: Cursor 1.7.3`.
  Use `^...$` when you want an exact value.
- Because these are Lua patterns and not plain text, escape magic characters
  (`.`, `-`, `+`, `(`, `)`, ...) with `%` if you mean them literally.
- Use `'.*'` to match on the mere presence of the trailer, whatever its value.
- Malformed patterns are ignored rather than raising an error.

## Highlight group

`VibeSignsDim` controls the sign's color. It is defined
automatically on `setup()` and redefined on every `ColorScheme` event using
`color`. To theme it yourself, either set `color` in `opts` or override the
highlight group after setup:

```lua
vim.api.nvim_set_hl(0, 'VibeSignsDim', { fg = '#9c6a2f' })

```

## Special thanks

[mat-1/slopcheck](https://github.com/mat-1/slopcheck) for some agent emails
