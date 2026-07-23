local M = {}

--- Parse `git blame --line-porcelain` output.
--- Each entry begins with a 40-hex header line: "<sha> <orig> <final> [<count>]".
--- Within an entry, "author-mail <email>" gives the author; a line starting
--- with a TAB is the file content. author-mail is only emitted the first time a
--- sha is seen, so we cache the last-known author per sha.
--- @param stdout string
--- @return { lines: string[], sha: string[], author: string[] }
function M.parse_blame_porcelain(stdout)
  local out = { lines = {}, sha = {}, author = {} }
  local sha_author = {} --- @type table<string,string>
  local cur_sha, cur_mail
  for _, line in ipairs(vim.split(stdout or '', '\n', { plain = true })) do
    local sha = line:match(
      '^(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x) %d+ %d+'
    )
    if sha then
      cur_sha = sha
      cur_mail = sha_author[sha]
    else
      local mail = line:match('^author%-mail <([^>]*)>')
      if mail then
        cur_mail = mail:gsub('%s+', ''):lower()
        if cur_sha then
          sha_author[cur_sha] = cur_mail
        end
      elseif line:sub(1, 1) == '\t' then
        out.lines[#out.lines + 1] = line:sub(2)
        out.sha[#out.sha + 1] = cur_sha
        out.author[#out.author + 1] = cur_mail or ''
      end
    end
  end
  return out
end

--- @param args string[]
--- @param cb fun(code: integer, stdout: string, stderr: string)
local function run(args, cb)
  local ok, err = pcall(vim.system, args, { text = true }, function(res)
    vim.schedule(function()
      cb(res.code, res.stdout or '', res.stderr or '')
    end)
  end)
  if not ok then
    vim.schedule(function()
      cb(1, '', tostring(err))
    end)
  end
end

--- @param dir string
--- @param cb fun(sha: string?)
function M.head_sha(dir, cb)
  run({ 'git', '-C', dir, 'rev-parse', 'HEAD' }, function(code, stdout)
    if code ~= 0 then
      return cb(nil)
    end
    local sha = vim.trim(stdout)
    cb(sha ~= '' and sha or nil)
  end)
end

--- @param dir string
--- @param cb fun(toplevel: string?)
function M.toplevel(dir, cb)
  run({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' }, function(code, stdout)
    if code ~= 0 then
      return cb(nil)
    end
    local top = vim.trim(stdout)
    cb(top ~= '' and top or nil)
  end)
end

--- @param dir string
--- @param relpath string
--- @param cb fun(stdout: string?)
function M.blame_head(dir, relpath, cb)
  run(
    { 'git', '-C', dir, 'blame', 'HEAD', '--line-porcelain', '--', relpath },
    function(code, stdout)
      cb(code == 0 and stdout or nil)
    end
  )
end

--- @param dir string
--- @param sha string
--- @param cb fun(emails: string[])
function M.coauthors(dir, sha, cb)
  run(
    { 'git', '-C', dir, 'show', '-s', '--format=%(trailers:key=Co-authored-by,valueonly)', sha },
    function(code, stdout)
      if code ~= 0 then
        return cb({})
      end
      local emails = {}
      for _, l in ipairs(vim.split(stdout, '\n', { plain = true })) do
        local e = l:match('<([^>]+)>') or l:match('(%S+@%S+)')
        if e then
          emails[#emails + 1] = e:gsub('%s+', ''):lower()
        end
      end
      cb(emails)
    end
  )
end

return M
