# gitsigns-vibecoded.nvim

Marks **committed** lines authored by an AI coding agent with a dim orange
`┃` bar in the `gitsigns.nvim` signcolumn, right alongside gitsigns' own
add/change/delete signs.

An "agent line" is any line whose `git blame` commit either:

- has an author email matching one of `agent_emails`, or
- has a `Co-authored-by: Name <email>` trailer matching one of `agent_emails`.

## Important limitation

**Unstaged / uncommitted agent code is intentionally NOT detectable.**
Detection works purely off `git blame` against `HEAD`, so a line only gets
the dim-orange marker once it has been committed with an agent's authorship
or co-author trailer. Lines you (or an agent) have just written but not yet
committed are invisible to this plugin — that's by design, not a bug: there
is no reliable way to attribute uncommitted working-tree text to an author.

As soon as you edit a previously-flagged line (even without committing),
the marker disappears, because the line no longer matches its `HEAD`
blame content.

## Requirements

- Neovim with `vim.system` / `vim.uv` (0.10+)
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) — used as the
  signcolumn host and as the `User GitSignsUpdate` update trigger. This
  plugin renders its own extmarks at a lower sign priority than gitsigns, so
  gitsigns' own signs always take visual precedence.
- `git` on `$PATH`

## Install (lazy.nvim)

```lua
{
  dir = '~/.local/share/nvim/gitsigns-vibecoded.nvim',
  dependencies = { 'lewis6991/gitsigns.nvim' },
  opts = {
    agent_emails = { 'noreply@anthropic.com' },
    match = 'exact',
  },
}
```

`opts` is passed straight to `setup()`.

## Setup / options

```lua
require('gitsigns-vibecoded').setup({
  enabled = true,
  sign_text = '┃',
  debounce_ms = 150,
  priority = 3, -- below gitsigns sign_priority (6)
  color = '#9c6a2f', -- dim orange
  match = 'exact', -- 'exact' | 'domain'
  agent_emails = {
    'noreply@anthropic.com', -- Claude / Claude Code
    'noreply@openai.com', -- Codex / ChatGPT
    'cursoragent@cursor.com', -- Cursor
    'devin@devin.ai', -- Devin
    '198982749+Copilot@users.noreply.github.com', -- GitHub Copilot agent
  },
})
```

These are exactly the defaults in `lua/gitsigns-vibecoded/config.lua`; any
key you omit falls back to the value shown above. `agent_emails` is
replaced wholesale if you supply it (not merged), so include every address
you want recognized, including the defaults if you still want them.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | `true` | Master on/off switch. When `false`, `setup()` does nothing further (no autocmds, no highlight). |
| `sign_text` | string | `'┃'` | Text placed in the signcolumn for flagged lines. |
| `debounce_ms` | number | `150` | Delay before re-computing signs after a buffer event, coalescing bursts of `BufReadPost` / `BufWritePost` / `User GitSignsUpdate`. |
| `priority` | number | `3` | Sign extmark priority. Kept below gitsigns' own sign priority (`6`) so gitsigns' add/change/delete marks always win the signcolumn slot. |
| `color` | string | `'#9c6a2f'` | Foreground color (hex) used to define the `GitSignsVibecodedDim` highlight group. |
| `match` | `'exact'` | `'domain'` | `'exact'` | How `agent_emails` are matched against blame/co-author emails. See below. |
| `agent_emails` | string[] | see above | Addresses (or `Name <email>`) recognized as AI agents. |

### `match` modes

- `'exact'` (default) — an email is flagged only if it is exactly equal
  (case-insensitively) to one of the entries in `agent_emails`.
- `'domain'` — an email is flagged if its domain (the part after `@`)
  matches the domain of any entry in `agent_emails`. Useful for agent
  platforms that mint a unique local-part per run/bot but share one domain,
  e.g. flagging every `*@devin.ai` address by listing just `devin@devin.ai`.

### Adding agent emails

Override `agent_emails` in `setup()` with the full list you want (it
replaces the defaults rather than extending them):

```lua
require('gitsigns-vibecoded').setup({
  agent_emails = {
    'noreply@anthropic.com',
    'noreply@openai.com',
    'my-internal-bot@mycompany.com',
  },
})
```

Entries may be a bare email (`a@b.com`) or a `Name <a@b.com>` form (only the
address inside `<...>` is used for matching); comparison is
case-insensitive and only cares about the email portion.

## Highlight group

`GitSignsVibecodedDim` controls the sign's color. It is defined
automatically on `setup()` and redefined on every `ColorScheme` event using
`color`. To theme it yourself, either set `color` in `opts` or override the
highlight group after setup:

```lua
vim.api.nvim_set_hl(0, 'GitSignsVibecodedDim', { fg = '#9c6a2f' })
```

## How it works, briefly

On `BufReadPost` / `BufWritePost` / the `User GitSignsUpdate` autocmd event
(debounced by `debounce_ms`), the plugin:

1. Resolves the buffer's git repo and path.
1. Runs `git blame --porcelain` once against `HEAD` (cached per blob/HEAD
   sha) to get each `HEAD` line's content and whether its commit is an
   agent commit (author email or `Co-authored-by` trailer match).
1. Diffs the `HEAD` blob against the current buffer text (`vim.diff`) to
   map still-unchanged agent lines onto their current buffer line numbers.
1. Places a `GitSignsVibecodedDim`-highlighted `sign_text` extmark on each
   mapped line, at `priority` (below gitsigns' signs).

Any error along the way (not a git repo, blame failure, etc.) silently
clears signs for that buffer rather than raising.
