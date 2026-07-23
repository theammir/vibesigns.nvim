local repo = require('tests.support.repo')
local blame = require('gitsigns-vibecoded.blame')
local config = require('gitsigns-vibecoded.config')

--- Run async blame.compute synchronously for tests.
local function compute_sync(dir, relpath, cfg)
  local done, result = false, nil
  blame.compute(dir, relpath, cfg, function(r)
    result = r
    done = true
  end)
  vim.wait(5000, function()
    return done
  end)
  return result
end

describe('blame.compute', function()
  it('flags lines from a co-authored agent commit', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'human line' }, { author = 'human@example.com' })
    repo.commit(dir, git, 'f.txt', { 'human line', 'agent line' }, { coauthor = 'noreply@anthropic.com' })

    local cfg = config.resolve()
    local r = compute_sync(dir, 'f.txt', cfg)
    assert.is_not_nil(r)
    assert.same({ 'human line', 'agent line' }, r.head_lines)
    assert.is_nil(r.agent[1]) -- human commit
    assert.is_true(r.agent[2]) -- agent co-authored commit
  end)

  it('flags lines whose author email is an agent', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'x' }, { author = 'devin@devin.ai' })
    local r = compute_sync(dir, 'f.txt', config.resolve())
    assert.is_true(r.agent[1])
  end)

  it('returns nil for an untracked file', function()
    local dir = repo.new()
    local r = compute_sync(dir, 'missing.txt', config.resolve())
    assert.is_nil(r)
  end)
end)
