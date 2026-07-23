local config = require('gitsigns-vibecoded.config')

describe('config.resolve', function()
  it('returns defaults when given nothing', function()
    local c = config.resolve()
    assert.equals(true, c.enabled)
    assert.equals('┃', c.sign_text)
    assert.equals(3, c.priority)
    assert.equals('#9c6a2f', c.color)
    assert.equals('exact', c.match)
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
  local list = { 'noreply@anthropic.com', 'devin@devin.ai' }

  it('exact matches full address, case-insensitive, angle-wrapped', function()
    assert.is_true(config.is_agent_email('Claude <NOREPLY@Anthropic.com>', list, 'exact'))
    assert.is_true(config.is_agent_email('devin@devin.ai', list, 'exact'))
    assert.is_false(config.is_agent_email('bob@anthropic.com', list, 'exact'))
  end)

  it('domain matches any address at a listed domain', function()
    assert.is_true(config.is_agent_email('bob@anthropic.com', list, 'domain'))
    assert.is_false(config.is_agent_email('bob@github.com', list, 'domain'))
  end)

  it('returns false on malformed input', function()
    assert.is_false(config.is_agent_email('not-an-email', list, 'exact'))
    assert.is_false(config.is_agent_email('', list, 'domain'))
  end)
end)
