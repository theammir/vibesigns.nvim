local git = require('vibesigns.git')

describe('git.parse_blame_porcelain', function()
  it('extracts content, sha and author email per line in order', function()
    local sample = table.concat({
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1 1 2',
      'author Alice',
      'author-mail <alice@human.com>',
      'summary first',
      'filename f.txt',
      '\tline one',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2 2',
      '\tline two',
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 5 3 1',
      'author Bot',
      'author-mail <noreply@anthropic.com>',
      'summary second',
      'filename f.txt',
      '\tline three',
    }, '\n')

    local r = git.parse_blame_porcelain(sample)
    assert.same({ 'line one', 'line two', 'line three' }, r.lines)
    assert.same({
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    }, r.sha)
    assert.same({ 'alice@human.com', 'alice@human.com', 'noreply@anthropic.com' }, r.author)
  end)
end)

describe('git.parse_trailers', function()
  it('returns ordered key/value pairs and skips non-trailer lines', function()
    local sample = table.concat({
      'Co-authored-by: Agent <a@b.com>',
      'Made-with: Cursor',
      '',
      'not a trailer line',
      'X-Empty:',
    }, '\n')
    assert.same({
      { key = 'Co-authored-by', value = 'Agent <a@b.com>' },
      { key = 'Made-with', value = 'Cursor' },
      { key = 'X-Empty', value = '' },
    }, git.parse_trailers(sample))
  end)

  it('handles empty and nil input', function()
    assert.same({}, git.parse_trailers(''))
    assert.same({}, git.parse_trailers(nil))
  end)
end)

describe('git.coauthor_emails', function()
  it('extracts lowercased emails from Co-authored-by trailers only', function()
    local trailers = {
      { key = 'Co-authored-by', value = 'Agent <NoReply@Anthropic.com>' },
      { key = 'co-authored-by', value = 'bare@example.com' },
      { key = 'Signed-off-by', value = 'Author <h@e.com>' },
      { key = 'Made-with', value = 'Cursor' },
    }
    assert.same({ 'noreply@anthropic.com', 'bare@example.com' }, git.coauthor_emails(trailers))
  end)
end)
