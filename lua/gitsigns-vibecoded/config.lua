local M = {}

M.defaults = {
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

--- @param email string
--- @param agent_emails string[]
--- @param match 'exact'|'domain'
--- @return boolean
function M.is_agent_email(email, agent_emails, match)
  local norm = normalize(email)
  if not norm then
    return false
  end
  if match == 'domain' then
    local domain = norm:match('@(.+)$')
    for _, a in ipairs(agent_emails) do
      local ad = (normalize(a) or ''):match('@(.+)$')
      if ad and domain == ad then
        return true
      end
    end
    return false
  end
  for _, a in ipairs(agent_emails) do
    if normalize(a) == norm then
      return true
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
