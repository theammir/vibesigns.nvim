local config = require('vibesigns.config')

describe('config.resolve', function()
  it('returns defaults when given nothing', function()
    local c = config.resolve()
    assert.equals(true, c.enabled)
    assert.equals('┃', c.sign_text)
    assert.equals(3, c.priority)
    assert.equals('#9c6a2f', c.color)
    assert.is_nil(c.match) -- global match removed; matching is now per-entry
    assert.is_true(vim.tbl_contains(c.agent_emails, 'noreply@anthropic.com'))
    assert.same({ 'Cursor' }, c.agent_trailers['Made-with'])
  end)

  it('overrides scalars but replaces agent_emails wholesale when provided', function()
    local c = config.resolve({ priority = 9, agent_emails = { 'x@y.z' } })
    assert.equals(9, c.priority)
    assert.same({ 'x@y.z' }, c.agent_emails)
  end)

  it('replaces agent_trailers wholesale, so defaults can be dropped', function()
    local c = config.resolve({ agent_trailers = { ['X-Bot'] = { 'thing' } } })
    assert.same({ ['X-Bot'] = { 'thing' } }, c.agent_trailers)
    assert.is_nil(c.agent_trailers['Made-with'])
  end)

  it('allows disabling trailer matching with an empty table', function()
    local c = config.resolve({ agent_trailers = {} })
    assert.same({}, c.agent_trailers)
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor', c.agent_trailers))
  end)

  it('does not mutate defaults', function()
    config.resolve({ priority = 99 })
    assert.equals(3, config.defaults.priority)
  end)

  it('does not mutate default rule tables via the resolved copy', function()
    local c = config.resolve()
    table.insert(c.agent_trailers['Made-with'], 'Sneaky')
    table.insert(c.agent_emails, 'sneaky@x.com')
    assert.same({ 'Cursor' }, config.defaults.agent_trailers['Made-with'])
    assert.is_false(vim.tbl_contains(config.defaults.agent_emails, 'sneaky@x.com'))
  end)
end)

describe('config.is_agent_trailer', function()
  local defaults = config.defaults.agent_trailers

  it('matches the default Made-with: Cursor trailer case-insensitively', function()
    assert.is_true(config.is_agent_trailer('Made-with', 'Cursor', defaults))
    assert.is_true(config.is_agent_trailer('made-with', 'cursor', defaults))
    assert.is_true(config.is_agent_trailer('MADE-WITH', 'CURSOR', defaults))
  end)

  it('tolerates a trailing colon and surrounding whitespace in the key', function()
    assert.is_true(config.is_agent_trailer(' Made-With: ', ' Cursor ', defaults))
  end)

  it('does not match a different key or value', function()
    assert.is_false(config.is_agent_trailer('Made-with', 'Neovim', defaults))
    assert.is_false(config.is_agent_trailer('Signed-off-by', 'Cursor', defaults))
  end)

  -- The signs mark code an agent wrote, not code that some automation touched,
  -- so non-agent tooling stays unflagged unless the user opts in.
  it('leaves non-agent tooling trailers alone under the defaults', function()
    assert.is_false(config.is_agent_trailer('Made-with', 'git-format-patch', defaults))
    assert.is_false(config.is_agent_trailer('X-Dependabot-Version', '2.0', defaults))
    assert.is_false(config.is_agent_trailer('Change-Id', 'I0d1e2f', defaults))
    assert.is_false(config.is_agent_trailer('Reviewed-by', 'Cursor', defaults))
  end)

  it('matches substrings, since patterns are unanchored', function()
    assert.is_true(config.is_agent_trailer('Made-with', 'Cursor 1.7.3', defaults))
  end)

  it('supports anchors for an exact value match', function()
    local rules = { ['Made-with'] = { '^cursor$' } }
    assert.is_true(config.is_agent_trailer('Made-with', 'Cursor', rules))
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor 1.7', rules))
  end)

  it('accepts a bare string value as a single pattern', function()
    local rules = { ['Made-with'] = 'Aider' }
    assert.is_true(config.is_agent_trailer('Made-with', 'Aider v1', rules))
  end)

  it("matches on key presence alone with '.*', even for an empty value", function()
    local rules = { ['X-Agent'] = { '.*' } }
    assert.is_true(config.is_agent_trailer('X-Agent', 'anything', rules))
    assert.is_true(config.is_agent_trailer('X-Agent', '', rules))
    assert.is_false(config.is_agent_trailer('Other', 'anything', rules))
  end)

  it('matches any pattern in the list', function()
    local rules = { ['Made-with'] = { 'cursor', 'zed agent' } }
    assert.is_true(config.is_agent_trailer('Made-with', 'Zed Agent', rules))
    assert.is_false(config.is_agent_trailer('Made-with', 'Zed', rules)) -- the editor, hand-written
  end)

  it('honours Lua character classes and quantifiers', function()
    local rules = { ['Agent-version'] = { '^claude%-%d+$' } }
    assert.is_true(config.is_agent_trailer('Agent-version', 'CLAUDE-4', rules))
    assert.is_false(config.is_agent_trailer('Agent-version', 'claude-code', rules))
  end)

  it('can opt out of case folding with ignore_case = false', function()
    local rules = { ['Made-with'] = { 'Cursor', ignore_case = false } }
    assert.is_true(config.is_agent_trailer('Made-with', 'Cursor', rules))
    assert.is_false(config.is_agent_trailer('Made-with', 'cursor', rules))
    -- the key stays case-insensitive regardless
    assert.is_true(config.is_agent_trailer('MADE-WITH', 'Cursor', rules))
  end)

  it('returns false for malformed keys, values, rules and patterns', function()
    assert.is_false(config.is_agent_trailer('', 'Cursor', defaults))
    assert.is_false(config.is_agent_trailer('Made-with', nil, defaults))
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor', nil))
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor', { ['Made-with'] = {} }))
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor', { ['Made-with'] = { '', 123 } }))
    -- an invalid pattern must not raise
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor', { ['Made-with'] = { '%' } }))
    assert.is_false(config.is_agent_trailer('Made-with', 'Cursor', { ['Made-with'] = { '[' } }))
  end)

  -- A user's config is arbitrary Lua, and it is read on every commit lookup,
  -- so a typo must never surface as an error while they are editing.
  it('never raises across the cross-product of odd keys, values and rules', function()
    local keys = { 'Made-with', '', 'x:', ':', 'a:b', ' Made-With : ', 123, false, {} }
    local values = { 'Cursor', '', ' ', '%', '[', 'a%1b', 'CURSOR 1.7', 42, {}, ('x'):rep(500) }
    local rules = {
      {},
      'not-a-table',
      42,
      { ['Made-with'] = 'Cursor' },
      { ['Made-with'] = { 'Cursor' } },
      { ['Made-with'] = { '%' } },
      { ['Made-with'] = { '[' } },
      { ['Made-with'] = { '(' } },
      { ['Made-with'] = { 123, '' } },
      { ['Made-with'] = true },
      { [123] = { 'Cursor' } },
      { ['Made-with'] = { '.*', ignore_case = false } },
      { ['Made-with'] = { ignore_case = 'yes' } },
      { ['made-with:'] = { 'cursor' } },
      { ['%'] = { '%' } },
    }
    for _, k in ipairs(keys) do
      for _, v in ipairs(values) do
        for _, r in ipairs(rules) do
          local ok, res = pcall(config.is_agent_trailer, k, v, r)
          assert.is_true(ok, 'raised for ' .. vim.inspect({ k, v, r }) .. ': ' .. tostring(res))
          assert.equals('boolean', type(res))
        end
      end
    end
  end)
end)

describe('config.is_agent_email', function()
  it('plain-string entry matches exactly, case-insensitive, angle-wrapped', function()
    local list = { 'noreply@anthropic.com', 'devin@devin.ai' }
    assert.is_true(config.is_agent_email('Claude <NOREPLY@Anthropic.com>', list))
    assert.is_true(config.is_agent_email('devin@devin.ai', list))
    assert.is_false(config.is_agent_email('bob@anthropic.com', list)) -- string entry = exact
  end)

  it('{ "domain", ... } entry matches any address at that bare domain', function()
    local list = { { 'domain', 'anthropic.com' } }
    assert.is_true(config.is_agent_email('bob@anthropic.com', list))
    assert.is_true(config.is_agent_email('Someone <ANY@Anthropic.com>', list))
    assert.is_false(config.is_agent_email('bob@github.com', list))
  end)

  it('{ "exact", ... } entry matches the full email', function()
    assert.is_true(config.is_agent_email('a@b.com', { { 'exact', 'a@b.com' } }))
    assert.is_true(config.is_agent_email('A@B.com', { { 'exact', 'a@b.com' } })) -- case-insensitive
    assert.is_false(config.is_agent_email('c@b.com', { { 'exact', 'a@b.com' } }))
  end)

  it('tolerates a "local@domain" value in a domain entry (keeps the domain)', function()
    local list = { { 'domain', 'x@agent.ai' } }
    assert.is_true(config.is_agent_email('someone@agent.ai', list))
  end)

  it('applies match mode per entry within one mixed list', function()
    local list = { 'exact@only.com', { 'domain', 'agent.ai' } }
    assert.is_true(config.is_agent_email('exact@only.com', list)) -- string entry: exact hit
    assert.is_false(config.is_agent_email('other@only.com', list)) -- string entry: not domain
    assert.is_true(config.is_agent_email('anyone@agent.ai', list)) -- table entry: domain hit
  end)

  it('returns false on malformed email or malformed entries', function()
    assert.is_false(config.is_agent_email('not-an-email', { 'a@b.com' }))
    assert.is_false(config.is_agent_email('', { { 'domain', 'a.com' } }))
    -- non-string/non-table, unknown mode, missing/non-string value → skipped
    assert.is_false(
      config.is_agent_email('a@b.com', { 123, {}, { 'nope', 'a@b.com' }, { 'exact' } })
    )
  end)

  -- Runs inside async blame callbacks, so a mistyped list must not raise.
  it('returns false instead of raising when the list is not a table', function()
    for _, bad in ipairs({ 'noreply@anthropic.com', 42, true }) do
      local ok, res = pcall(config.is_agent_email, 'a@b.com', bad)
      assert.is_true(ok, 'raised for ' .. vim.inspect(bad))
      assert.is_false(res)
    end
    local ok, res = pcall(config.is_agent_email, 'a@b.com', nil)
    assert.is_true(ok)
    assert.is_false(res)
  end)
end)
