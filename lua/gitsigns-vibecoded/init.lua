local config = require('gitsigns-vibecoded.config')
local blame = require('gitsigns-vibecoded.blame')
local map = require('gitsigns-vibecoded.map')
local signs = require('gitsigns-vibecoded.signs')
local git = require('gitsigns-vibecoded.git')

local api = vim.api

local M = {}

M.config = nil
M._last_refresh_done = nil -- test hook: bufnr of the most recently completed refresh
local timers = {} --- @type table<integer, uv_timer_t>
local toplevel_cache = {} --- @type table<string, string> parent-dir -> toplevel

--- Cheap, synchronous, non-git pre-checks. Returns the absolute path and its
--- parent directory, or nil if the buffer is unsuitable.
--- @param bufnr integer
--- @return string? abs, string? parent_dir
local function precheck(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local name = api.nvim_buf_get_name(bufnr)
  if name == '' or vim.bo[bufnr].buftype ~= '' then
    return nil
  end
  local abs = vim.fn.fnamemodify(name, ':p')
  if vim.fn.filereadable(abs) ~= 1 then
    return nil
  end
  local dir = vim.fn.fnamemodify(abs, ':h')
  return abs, dir
end

--- @param bufnr integer
--- @param abs string
--- @param toplevel string?
local function on_toplevel(bufnr, abs, toplevel)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not toplevel or toplevel == '' then
    signs.clear(bufnr)
    M._last_refresh_done = bufnr
    return
  end
  local relpath = abs:sub(#toplevel + 2)
  blame.compute(toplevel, relpath, M.config, function(res)
    if not api.nvim_buf_is_valid(bufnr) then
      return
    end
    if not res then
      signs.clear(bufnr)
      M._last_refresh_done = bufnr
      return
    end
    local buf_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ok = pcall(function()
      local lines = map.current_agent_lines(res.head_lines, buf_lines, res.agent)
      signs.set(bufnr, lines, M.config)
    end)
    if not ok then
      signs.clear(bufnr)
    end
    M._last_refresh_done = bufnr
  end)
end

--- @param bufnr integer
function M.refresh(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not M.config or not M.config.enabled then
    return
  end
  local abs, dir = precheck(bufnr)
  if not abs then
    signs.clear(bufnr)
    M._last_refresh_done = bufnr
    return
  end
  local cached = toplevel_cache[dir]
  if cached then
    on_toplevel(bufnr, abs, cached)
    return
  end
  git.toplevel(dir, function(toplevel)
    if toplevel and toplevel ~= '' then
      toplevel_cache[dir] = toplevel
    end
    on_toplevel(bufnr, abs, toplevel)
  end)
end

--- @param bufnr integer
local function schedule_refresh(bufnr)
  local ms = M.config.debounce_ms
  local existing = timers[bufnr]
  if existing then
    existing:stop()
    if not existing:is_closing() then
      existing:close()
    end
  end
  local t = vim.uv.new_timer()
  timers[bufnr] = t
  t:start(ms, 0, function()
    if not t:is_closing() then
      t:stop()
      t:close()
    end
    if timers[bufnr] == t then
      timers[bufnr] = nil
    end
    vim.schedule(function()
      M.refresh(bufnr)
    end)
  end)
end

local function define_hl()
  api.nvim_set_hl(0, 'GitSignsVibecodedDim', { fg = M.config.color, default = false })
end

--- @param opts table?
function M.setup(opts)
  blame._reset_cache()
  toplevel_cache = {}
  M.config = config.resolve(opts)
  if not M.config.enabled then
    return
  end
  define_hl()
  local group = api.nvim_create_augroup('GitSignsVibecoded', { clear = true })
  api.nvim_create_autocmd('ColorScheme', { group = group, callback = define_hl })
  api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
    group = group,
    callback = function(ev)
      schedule_refresh(ev.buf)
    end,
  })
  api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'GitSignsUpdate',
    callback = function(ev)
      local buf = (ev.data and ev.data.buffer) or api.nvim_get_current_buf()
      schedule_refresh(buf)
    end,
  })
end

return M
