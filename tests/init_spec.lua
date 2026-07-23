local repo = require('tests.support.repo')
local gv = require('vibesigns.init')

local function refresh_sync(bufnr)
  gv.refresh(bufnr)
  vim.wait(5000, function()
    return #vim.api.nvim_buf_get_extmarks(bufnr, require('vibesigns.signs').ns, 0, -1, {}) > 0
      or gv._last_refresh_done == bufnr
  end)
end

describe('gitsigns-vibecoded end-to-end', function()
  it('signs committed agent lines, ignores human and modified lines', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'human1' }, { author = 'human@example.com' })
    repo.commit(
      dir,
      git,
      'f.txt',
      { 'human1', 'agentline' },
      { coauthor = 'noreply@anthropic.com' }
    )

    gv.setup({})
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, dir .. '/f.txt')
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('edit!')
    end)

    refresh_sync(buf)

    local ns = require('vibesigns.signs').ns
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    local rows = {}
    for _, m in ipairs(marks) do
      rows[#rows + 1] = m[2]
    end
    assert.same({ 1 }, rows) -- only buffer row 1 (0-based) = 'agentline'
  end)

  it('signs agent lines for a file in a subdirectory', function()
    local dir, git = repo.new()
    vim.fn.mkdir(dir .. '/sub', 'p')
    repo.commit(dir, git, 'sub/f.txt', { 'human1' }, { author = 'human@example.com' })
    repo.commit(
      dir,
      git,
      'sub/f.txt',
      { 'human1', 'agentline' },
      { coauthor = 'noreply@anthropic.com' }
    )

    gv.setup({})
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, dir .. '/sub/f.txt')
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('edit!')
    end)

    refresh_sync(buf)

    local ns = require('vibesigns.signs').ns
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    local rows = {}
    for _, m in ipairs(marks) do
      rows[#rows + 1] = m[2]
    end
    assert.same({ 1 }, rows) -- only buffer row 1 (0-based) = 'agentline'
  end)

  it('setup with enabled=false places no signs', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'x' }, { coauthor = 'noreply@anthropic.com' })
    require('vibesigns.blame')._reset_cache()
    gv.setup({ enabled = false })
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, dir .. '/f.txt')
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('edit!')
    end)
    gv.refresh(buf)
    vim.wait(1000)
    local ns = require('vibesigns.signs').ns
    assert.equals(0, #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}))
  end)
end)
