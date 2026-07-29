local repo = require('tests.support.repo')
local blame = require('vibesigns.blame')
local config = require('vibesigns.config')

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
    repo.commit(
      dir,
      git,
      'f.txt',
      { 'human line', 'agent line' },
      { coauthor = 'noreply@anthropic.com' }
    )

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

  it('flags lines from a commit carrying the default Made-with: Cursor trailer', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'human line' }, { author = 'human@example.com' })
    repo.commit(dir, git, 'f.txt', { 'human line', 'agent line' }, {
      author = 'human@example.com',
      trailers = { 'Made-with: Cursor' },
    })

    local r = compute_sync(dir, 'f.txt', config.resolve())
    assert.is_not_nil(r)
    assert.is_nil(r.agent[1])
    assert.is_true(r.agent[2])
  end)

  it('flags lines via a user-configured trailer pattern, ignoring other trailers', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'a' }, {
      author = 'human@example.com',
      trailers = { 'Signed-off-by: Author <human@example.com>', 'X-Agent: aider v0.9' },
    })

    local hit = compute_sync(dir, 'f.txt', config.resolve({
      agent_trailers = { ['x-agent'] = { '^aider' } },
    }))
    assert.is_true(hit.agent[1])

    -- sha agent-ness is cached per sha, so drop caches before re-matching.
    blame._reset_cache()
    local miss = compute_sync(dir, 'f.txt', config.resolve({
      agent_trailers = { ['x-agent'] = { '^cursor' } },
    }))
    assert.is_nil(miss.agent[1])
  end)

  -- Only agent authorship is signed. Other trailers, including those added by
  -- non-agent tooling, are left alone unless the user configures them.
  it('does not flag a hand-written commit that merely carries other trailers', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'a' }, {
      author = 'human@example.com',
      trailers = {
        'Signed-off-by: Author <human@example.com>',
        'Change-Id: I0d1e2f3a',
        'Made-with: Neovim',
      },
    })
    local r = compute_sync(dir, 'f.txt', config.resolve())
    assert.is_nil(r.agent[1])
  end)

  -- A mistyped option must degrade to "nothing flagged", not break the refresh.
  it('survives a mistyped config without raising', function()
    local dir, git = repo.new()
    repo.commit(dir, git, 'f.txt', { 'a' }, {
      author = 'human@example.com',
      trailers = { 'Made-with: Cursor' },
    })
    for _, cfg in ipairs({
      { agent_emails = 'oops', agent_trailers = {} },
      { agent_emails = {}, agent_trailers = 'oops' },
      { agent_emails = nil, agent_trailers = nil },
    }) do
      blame._reset_cache()
      local ok, res = pcall(compute_sync, dir, 'f.txt', cfg)
      assert.is_true(ok, 'raised for ' .. vim.inspect(cfg))
      assert.is_not_nil(res)
      assert.is_nil(res.agent[1])
    end
  end)
end)
