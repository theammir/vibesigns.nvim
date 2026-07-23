local M = {}

--- @param lines string[]
--- @return string
local function joined(lines)
  if #lines == 0 then
    return ''
  end
  return table.concat(lines, '\n') .. '\n'
end

--- Map unchanged buffer lines back to HEAD lines and keep agent ones.
--- Uses vim.diff indices: each hunk is {start_a, count_a, start_b, count_b}.
--- For count==0 hunks, start_* is the line AFTER which the change sits.
--- @param head_lines string[]
--- @param buf_lines string[]
--- @param agent table<integer,boolean>
--- @return integer[]
function M.current_agent_lines(head_lines, buf_lines, agent)
  local diff = vim.diff(joined(head_lines), joined(buf_lines), { result_type = 'indices' })
  --- @cast diff integer[][]
  local result = {}
  local ai, bi = 1, 1 -- next unprocessed HEAD line / buffer line (1-based)
  for _, h in ipairs(diff or {}) do
    local _, ca, sb, cb = h[1], h[2], h[3], h[4]
    -- Buffer lines before this hunk are context (1:1 with HEAD).
    local b_stop = cb > 0 and sb or (sb + 1)
    while bi < b_stop do
      if agent[ai] then
        result[#result + 1] = bi
      end
      ai = ai + 1
      bi = bi + 1
    end
    -- Skip the changed region on both sides.
    ai = ai + ca
    bi = bi + cb
  end
  -- Trailing context.
  while bi <= #buf_lines do
    if agent[ai] then
      result[#result + 1] = bi
    end
    ai = ai + 1
    bi = bi + 1
  end
  return result
end

return M
