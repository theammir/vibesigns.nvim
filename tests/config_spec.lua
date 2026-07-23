local config = require('gitsigns-vibecoded.config')

describe('config.resolve', function()
  it('returns defaults when given nothing', function()
    local c = config.resolve()
    assert.equals(true, c.enabled)
    assert.equals('┃', c.sign_text)
    assert.equals(3, c.priority)
    assert.equals('#9c6a2f', c.color)
    assert.is_nil(c.match) -- global match removed; matching is now per-entry
    assert.is_true(vim.tbl_contains(c.agent_emails, 'noreply@anthropic.com'))
  end)

  it('overrides scalars but replaces agent_emails wholesale when provided', function()
    local c = config.resolve({ priority = 9, agent_emails = { 'x@y.z' } })
    assert.equals(9, c.priority)
    assert.same({ 'x@y.z' }, c.agent_emails)
  end)

  it('does not mutate defaults', function()
    config.resolve({ priority = 99 })
    assert.equals(3, config.defaults.priority)
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
    assert.is_false(config.is_agent_email('a@b.com', { 123, {}, { 'nope', 'a@b.com' }, { 'exact' } }))
  end)
end)
