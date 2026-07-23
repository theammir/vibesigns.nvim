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
    'noreply@openai.com', -- Codex / ChatGPT
    'cursoragent@cursor.com', -- Cursor
    'devin@devin.ai', -- Devin
    '198982749+Copilot@users.noreply.github.com', -- GitHub Copilot agent
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

--- Is `email` (bare or angle-wrapped) an agent address per the entry list?
--- Match mode is decided per entry (see normalize_entry).
--- @param email string
--- @param agent_emails (string|table)[]
--- @return boolean
function M.is_agent_email(email, agent_emails)
  local norm = normalize(email)
  if not norm then
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

--- @param opts table?
--- @return table
function M.resolve(opts)
  return vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
end

return M
