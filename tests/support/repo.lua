local M = {}

--- Create a throwaway git repo in a temp dir. Returns its path.
--- @return string dir
function M.new()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local function git(...)
    local args = { 'git', '-C', dir }
    vim.list_extend(args, { ... })
    local res = vim.system(args, { text = true }):wait()
    assert(res.code == 0, 'git failed: ' .. table.concat({ ... }, ' ') .. '\n' .. (res.stderr or ''))
    return res.stdout
  end
  git('init', '-q')
  git('config', 'user.name', 'Human')
  git('config', 'user.email', 'human@example.com')
  return dir, git
end

--- Write file (list of lines) then commit, optionally as an agent co-author.
--- @param dir string
--- @param git fun(...):string
--- @param relpath string
--- @param lines string[]
--- @param opts { msg?: string, coauthor?: string, author?: string }?
function M.commit(dir, git, relpath, lines, opts)
  opts = opts or {}
  local path = dir .. '/' .. relpath
  vim.fn.writefile(lines, path)
  git('add', relpath)
  local msg = opts.msg or 'change'
  if opts.coauthor then
    msg = msg .. '\n\nCo-authored-by: Agent <' .. opts.coauthor .. '>'
  end
  local env = {}
  if opts.author then
    env = { GIT_AUTHOR_EMAIL = opts.author, GIT_COMMITTER_EMAIL = opts.author }
  end
  local args = { 'git', '-C', dir, 'commit', '-q', '-m', msg }
  local res = vim.system(args, { text = true, env = env }):wait()
  assert(res.code == 0, res.stderr or 'commit failed')
end

return M
