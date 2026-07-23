local signs = require('vibesigns.signs')
local config = require('vibesigns.config')

local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

describe('signs', function()
  it('places one extmark per requested line with correct props', function()
    local buf = make_buf({ 'a', 'b', 'c' })
    signs.set(buf, { 1, 3 }, config.resolve())
    local marks = vim.api.nvim_buf_get_extmarks(buf, signs.ns, 0, -1, { details = true })
    assert.equals(2, #marks)
    local rows = { marks[1][2], marks[2][2] }
    table.sort(rows)
    assert.same({ 0, 2 }, rows) -- 0-based rows for lines 1 and 3
    assert.equals('VibeSignsDim', marks[1][4].sign_hl_group)
    -- Neovim right-pads narrow sign_text to fill the signcolumn's 2-cell
    -- width when storing/reading extmarks, so trim before comparing.
    assert.equals('┃', vim.trim(marks[1][4].sign_text))
    assert.equals(3, marks[1][4].priority)
  end)

  it('set replaces previous marks; clear removes them', function()
    local buf = make_buf({ 'a', 'b', 'c' })
    signs.set(buf, { 1, 2, 3 }, config.resolve())
    signs.set(buf, { 2 }, config.resolve())
    assert.equals(1, #vim.api.nvim_buf_get_extmarks(buf, signs.ns, 0, -1, {}))
    signs.clear(buf)
    assert.equals(0, #vim.api.nvim_buf_get_extmarks(buf, signs.ns, 0, -1, {}))
  end)
end)
