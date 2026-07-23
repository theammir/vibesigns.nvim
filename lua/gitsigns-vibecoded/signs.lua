local api = vim.api

local M = {}

M.ns = api.nvim_create_namespace('gitsigns_vibecoded')

--- @param bufnr integer
function M.clear(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
  end
end

--- @param bufnr integer
--- @param lines integer[]  1-based line numbers
--- @param cfg table
function M.set(bufnr, lines, cfg)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  M.clear(bufnr)
  local count = api.nvim_buf_line_count(bufnr)
  for _, lnum in ipairs(lines) do
    if lnum >= 1 and lnum <= count then
      pcall(api.nvim_buf_set_extmark, bufnr, M.ns, lnum - 1, 0, {
        sign_text = cfg.sign_text,
        sign_hl_group = 'GitSignsVibecodedDim',
        priority = cfg.priority,
      })
    end
  end
end

return M
