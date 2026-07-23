local git = require('gitsigns-vibecoded.git')

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
