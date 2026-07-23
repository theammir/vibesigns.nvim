local map = require('vibesigns.map')

describe('map.current_agent_lines', function()
  it('identity when buffer equals HEAD', function()
    local head = { 'a', 'b', 'c' }
    local r = map.current_agent_lines(head, { 'a', 'b', 'c' }, { [2] = true })
    assert.same({ 2 }, r)
  end)

  it('shifts down when lines inserted above an agent line', function()
    local head = { 'a', 'agent' } -- head line 2 is agent
    local buf = { 'a', 'new1', 'new2', 'agent' } -- agent now at buffer line 4
    local r = map.current_agent_lines(head, buf, { [2] = true })
    assert.same({ 4 }, r)
  end)

  it('shifts up when lines deleted above an agent line', function()
    local head = { 'a', 'b', 'agent' } -- head line 3 is agent
    local buf = { 'a', 'agent' } -- agent now at buffer line 2
    local r = map.current_agent_lines(head, buf, { [3] = true })
    assert.same({ 2 }, r)
  end)

  it('does not flag a modified agent line', function()
    local head = { 'agent' } -- head line 1 is agent
    local buf = { 'agent edited' } -- content changed
    local r = map.current_agent_lines(head, buf, { [1] = true })
    assert.same({}, r)
  end)

  it('flags multiple agent lines around edits', function()
    local head = { 'a1', 'h', 'a2' } -- lines 1 and 3 agent
    local buf = { 'a1', 'h changed', 'a2' }
    local r = map.current_agent_lines(head, buf, { [1] = true, [3] = true })
    assert.same({ 1, 3 }, r)
  end)

  it('handles two separate hunks in one diff', function()
    -- head lines 1,3,5 (a1,a2,a3) are agent lines; h1,h2 are plain context.
    local head = { 'a1', 'h1', 'a2', 'h2', 'a3' }
    -- Hunk 1: an insertion above everything (shifts all following lines by 1).
    -- Hunk 2: h1 is modified (pure replacement, no additional shift).
    -- a1, a2, a3 are themselves untouched by either hunk, so all three survive,
    -- each shifted down by exactly 1 buffer line from their HEAD position.
    local buf = { 'ins', 'a1', 'h1 modified', 'a2', 'h2', 'a3' }
    local r = map.current_agent_lines(head, buf, { [1] = true, [3] = true, [5] = true })
    assert.same({ 2, 4, 6 }, r)
  end)

  it('excludes a deleted agent line', function()
    -- HEAD line 2 ('agentgone') is the only agent line, and it is deleted
    -- entirely from the buffer, so nothing can survive in the result.
    local head = { 'keep1', 'agentgone', 'keep2' }
    local buf = { 'keep1', 'keep2' }
    local r = map.current_agent_lines(head, buf, { [2] = true })
    assert.same({}, r)
  end)

  it('handles an edit exactly at buffer line 1 with no leading context', function()
    -- HEAD line 1 ('agent1') is agent. A new line is inserted before it with
    -- no unchanged line preceding the insertion, pushing agent1 to buffer
    -- line 2.
    local head = { 'agent1', 'b' }
    local buf = { 'inserted', 'agent1', 'b' }
    local r = map.current_agent_lines(head, buf, { [1] = true })
    assert.same({ 2 }, r)
  end)

  it('returns empty when the whole buffer is replaced', function()
    -- Both HEAD lines are agent lines, but every line is replaced, so no
    -- agent line is unchanged in the buffer.
    local head = { 'a', 'b' }
    local buf = { 'x', 'y' }
    local r = map.current_agent_lines(head, buf, { [1] = true, [2] = true })
    assert.same({}, r)
  end)
end)
