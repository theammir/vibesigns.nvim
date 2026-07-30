local M = {}

M.defaults = {
  enabled = true,
  sign_text = '┃',
  debounce_ms = 150,
  priority = 3, -- below gitsigns sign_priority (6)
  color = '#9c6a2f', -- dim orange
  -- Each entry is either a plain string (matched exactly) or a positional
  -- table { mode, value }: { 'exact', '<email>' } or { 'domain', '<domain>' }.
  -- 'domain' matches any address at that bare domain (e.g. { 'domain', 'devin.ai' }).
  agent_emails = {
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
    '165735046+greptile-apps[bot]@users.noreply.github.com', -- Greptile (PR review)
    '136622811+coderabbitai[bot]@users.noreply.github.com', -- CodeRabbit (PR review)
    '96075541+graphite-app[bot]@users.noreply.github.com', -- Graphite (PR review)
    'aider@aider.chat', -- Aider.ai
    'openhands@all-hands.dev', -- OpenHands
    '218195315+gemini-cli@users.noreply.github.com', -- Gemini
    '176961590+gemini-code-assist[bot]@users.noreply.github.com',
    '161369871+google-labs-jules[bot]@users.noreply.github.com', -- Google Jules
    '208079219+amazon-q-developer[bot]@users.noreply.github.com', -- Amazon Q
    '138933559+factory-droid[bot]@users.noreply.github.com', -- Factory.ai
    'amp@ampcode.com', -- Amp
    'amp@sourcegraph.com',
    'junie@jetbrains.com>', -- JetBrains
    'agent@replit.com', -- Replit
    '189301087+windsurf-bot[bot]@users.noreply.github.com', -- Windsurf
    'assistant@zed.dev', -- Zed
    'agent@warp.dev', -- Warp
    'v0[bot]@users.noreply.github.com', -- Vercel v0
    '240665456+kilo-code-bot[bot]@users.noreply.github.com', -- Kilo.ai
  },
  -- Arbitrary commit trailers, beyond Co-authored-by. Keys are trailer names
  -- (matched case-insensitively); each value is a Lua pattern, or a list of
  -- them, matched unanchored and case-insensitively against the trailer value.
  agent_trailers = {
    ['Made-with'] = { 'Cursor' }, -- Cursor
  },
}

--- Extract a bare lowercased email from "Name <a@b>" or "a@b".
--- @param s string
--- @return string?
local function normalize(s)
  if type(s) ~= 'string' then
    return nil
  end
  local inside = s:match('<([^>]+)>')
  local email = (inside or s):gsub('%s+', ''):lower()
  if email == '' or not email:find('@', 1, true) then
    return nil
  end
  return email
end

--- Normalize one agent_emails entry to { mode = 'exact'|'domain', value = ... }.
--- Accepts:
---   * a plain string           → exact match against the full email
---   * { 'exact', '<email>' }    → exact match against the full email
---   * { 'domain', '<domain>' }  → match any address whose domain equals this
--- For 'domain' the value is a bare domain (e.g. 'devin.ai'); an accidental
--- 'local@domain' form is tolerated by keeping only the part after '@'.
--- @param entry string|table
--- @return { mode: string, value: string }?
local function normalize_entry(entry)
  if type(entry) == 'string' then
    local email = normalize(entry)
    return email and { mode = 'exact', value = email } or nil
  end
  if type(entry) ~= 'table' then
    return nil
  end
  local mode, value = entry[1], entry[2]
  if type(mode) ~= 'string' or type(value) ~= 'string' then
    return nil
  end
  mode = mode:gsub('%s+', ''):lower()
  if mode == 'domain' then
    local domain = value:gsub('%s+', ''):lower():match('@?([^@]+)$')
    return (domain and domain ~= '') and { mode = 'domain', value = domain } or nil
  end
  if mode == 'exact' then
    local email = normalize(value)
    return email and { mode = 'exact', value = email } or nil
  end
  return nil
end

--- Lowercase the literal letters of a Lua pattern while leaving `%`-escapes
--- (character classes such as `%a`, `%D`) intact, so the pattern keeps its
--- meaning when matched against a lowercased subject.
--- @param pat string
--- @return string
local function lower_pattern(pat)
  local out, i, n = {}, 1, #pat
  while i <= n do
    local c = pat:sub(i, i)
    if c == '%' then
      out[#out + 1] = pat:sub(i, math.min(i + 1, n))
      i = i + 2
    else
      out[#out + 1] = c:lower()
      i = i + 1
    end
  end
  return table.concat(out)
end

--- Canonical form of a trailer key: trimmed, lowercased, trailing ':' dropped.
--- @param key string
--- @return string?
local function normalize_key(key)
  if type(key) ~= 'string' then
    return nil
  end
  local k = vim.trim(key):gsub(':%s*$', ''):lower()
  return k ~= '' and k or nil
end

--- Is `email` (bare or angle-wrapped) an agent address per the entry list?
--- Match mode is decided per entry (see normalize_entry).
--- @param email string
--- @param agent_emails (string|table)[]?
--- @return boolean
function M.is_agent_email(email, agent_emails)
  local norm = normalize(email)
  -- Called from async blame callbacks on every commit lookup, so a mistyped
  -- config must return false rather than raise into the user's session.
  if not norm or type(agent_emails) ~= 'table' then
    return false
  end
  local norm_domain = norm:match('@(.+)$')
  for _, entry in ipairs(agent_emails) do
    local e = normalize_entry(entry)
    if e then
      if e.mode == 'domain' then
        if norm_domain and norm_domain == e.value then
          return true
        end
      elseif norm == e.value then
        return true
      end
    end
  end
  return false
end

--- Does the trailer `key: value` match any configured agent trailer rule?
--- Keys compare case-insensitively; values are tested with `string.find`
--- against each configured Lua pattern (unanchored, case-insensitive), so
--- `'Cursor'` matches `Made-with: Cursor 1.7`. Anchor with `^...$` for an
--- exact match. A rule may opt out of case folding with
--- `{ 'Cursor', ignore_case = false }`.
--- @param key string
--- @param value string
--- @param agent_trailers table<string, string|table>?
--- @return boolean
function M.is_agent_trailer(key, value, agent_trailers)
  local k = normalize_key(key)
  if not k or type(value) ~= 'string' or type(agent_trailers) ~= 'table' then
    return false
  end
  local trimmed = vim.trim(value)
  for rule_key, patterns in pairs(agent_trailers) do
    if normalize_key(rule_key) == k then
      if type(patterns) == 'string' then
        patterns = { patterns }
      end
      if type(patterns) == 'table' then
        local fold = patterns.ignore_case ~= false
        local subject = fold and trimmed:lower() or trimmed
        for _, pat in ipairs(patterns) do
          if type(pat) == 'string' and pat ~= '' then
            local ok, found = pcall(string.find, subject, fold and lower_pattern(pat) or pat)
            if ok and found then
              return true
            end
          end
        end
      end
    end
  end
  return false
end

--- @param opts table?
--- @return table
function M.resolve(opts)
  opts = opts or {}
  local cfg = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
  -- Rule collections are replaced wholesale, never merged key-by-key, so a
  -- user list is exactly what gets matched (and defaults can be dropped).
  if opts.agent_emails ~= nil then
    cfg.agent_emails = vim.deepcopy(opts.agent_emails)
  end
  if opts.agent_trailers ~= nil then
    cfg.agent_trailers = vim.deepcopy(opts.agent_trailers)
  end
  return cfg
end

return M
