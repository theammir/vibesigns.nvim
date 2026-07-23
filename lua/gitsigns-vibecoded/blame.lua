local git = require('gitsigns-vibecoded.git')
local config = require('gitsigns-vibecoded.config')

local M = {}

-- Cache: agent-ness per sha, per (dir). Session-lived.
local sha_is_agent = {} --- @type table<string, boolean>
-- Cache: computed result per (dir|relpath|head_sha).
local result_cache = {} --- @type table<string, { head_lines: string[], agent: table<integer,boolean> }>

--- @param dir string
--- @param relpath string
--- @param cfg table
--- @param cb fun(res: { head_lines: string[], agent: table<integer,boolean> }?)
function M.compute(dir, relpath, cfg, cb)
  git.head_sha(dir, function(head)
    if not head then
      return cb(nil)
    end
    local key = dir .. '|' .. relpath .. '|' .. head
    if result_cache[key] then
      return cb(result_cache[key])
    end
    git.blame_head(dir, relpath, function(stdout)
      if not stdout then
        return cb(nil)
      end
      local parsed = git.parse_blame_porcelain(stdout)
      if #parsed.lines == 0 then
        return cb(nil)
      end

      -- Distinct shas whose author is not already agent → need trailer check.
      local shas_needing_trailer = {} --- @type table<string, boolean>
      for i = 1, #parsed.lines do
        local sha = parsed.sha[i]
        if sha_is_agent[sha] == nil then
          if config.is_agent_email(parsed.author[i], cfg.agent_emails) then
            sha_is_agent[sha] = true
          else
            shas_needing_trailer[sha] = true
          end
        end
      end

      local pending = vim.tbl_keys(shas_needing_trailer)
      local function finish()
        local agent = {}
        for i = 1, #parsed.lines do
          if sha_is_agent[parsed.sha[i]] then
            agent[i] = true
          end
        end
        local res = { head_lines = parsed.lines, agent = agent }
        result_cache[key] = res
        cb(res)
      end

      if #pending == 0 then
        return finish()
      end
      local remaining = #pending
      for _, sha in ipairs(pending) do
        git.coauthors(dir, sha, function(emails)
          local is_agent = false
          for _, e in ipairs(emails) do
            if config.is_agent_email(e, cfg.agent_emails) then
              is_agent = true
              break
            end
          end
          sha_is_agent[sha] = is_agent
          remaining = remaining - 1
          if remaining == 0 then
            finish()
          end
        end)
      end
    end)
  end)
end

--- Test/maintenance hook: drop all caches.
function M._reset_cache()
  sha_is_agent = {}
  result_cache = {}
end

return M
