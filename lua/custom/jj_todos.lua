-- Scan for TODO/FIXME/IDEA markers across a jj (Jujutsu) revset and
-- collect them into the quickfix list.
--
-- Since the working copy is the tip of any descendant chain, we scan the
-- on-disk files that belong to the revset. Line numbers therefore always
-- point at real, openable locations.

local M = {}

local function system_list(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('jj failed: ' .. vim.fn.join(vim.split(vim.fn.system(cmd), '\n'), ' '), vim.log.levels.ERROR)
    return nil
  end
  return out
end

-- Resolve a list of relative file names (from jj) to absolute working-copy paths
-- that actually exist on disk.
local function resolve_files(names)
  local cwd = vim.fn.getcwd()
  local files = {}
  for _, rel in ipairs(names) do
    rel = (rel:gsub('^"', ''):gsub('"$', ''))
    local abs = cwd .. '/' .. rel
    if vim.fn.filereadable(abs) == 1 then
      table.insert(files, abs)
    end
  end
  return files
end

-- Get the files belonging to a jj revision / revset.
local function files_for_revset(revset)
  local names = system_list('jj file list -r ' .. vim.fn.shellescape(revset))
  if not names then
    return nil
  end
  return resolve_files(names)
end

-- Get files changed between a base revision and the working copy (@).
local function files_descendants(base)
  local names = system_list('jj diff --from ' .. vim.fn.shellescape(base) .. ' --to @ --name-only')
  if not names then
    return nil
  end
  return resolve_files(names)
end

-- Scan explicit files with the same rg invocation todo-comments uses,
-- feeding results through its parser so tagging/highlighting match.
local function scan_files(files, opts, cb)
  local tc = require 'todo-comments'
  local Config = require 'todo-comments.config'
  local Search = require 'todo-comments.search'
  if not Config.loaded then
    vim.notify('todo-comments is not loaded', vim.log.levels.ERROR)
    return
  end

  local command = Config.options.search.command
  if vim.fn.executable(command) ~= 1 then
    vim.notify(command .. ' not found', vim.log.levels.ERROR)
    return
  end

  local keywords = vim.tbl_keys(Config.keywords)
  if opts.keywords then
    local filters = vim.split(opts.keywords, ',')
    keywords = vim.tbl_filter(function(kw)
      return vim.tbl_contains(filters, kw)
    end, keywords)
  end

  local args = {}
  vim.list_extend(args, Config.options.search.args)
  vim.list_extend(args, { (Config.search_regex(keywords)) })
  vim.list_extend(args, files)

  local ok, Job = pcall(require, 'plenary.job')
  if not ok then
    vim.notify('requires plenary.nvim', vim.log.levels.ERROR)
    return
  end

  Job:new({
    command = command,
    args = args,
    on_exit = vim.schedule_wrap(function(j, code)
      if code == 2 then
        vim.notify(table.concat(j:stderr_result(), '\n'), vim.log.levels.ERROR)
        return
      end
      if code == 1 then
        vim.notify('no todos found in revset', vim.log.levels.WARN)
        return
      end
      local items = Search.process(j:result())
      if #items == 0 then
        vim.notify('no todos found in revset', vim.log.levels.WARN)
        return
      end
      vim.fn.setqflist({}, ' ', { title = 'Todo (jj)', id = '$', items = items })
      vim.cmd 'copen'
      local win = vim.fn.getqflist { winid = true }
      if win.winid ~= 0 then
        require('todo-comments.highlight').attach(win.winid, true)
      end
    end),
  }):start()
end

--- Scan the working copy (@) for todo comments.
function M.todo()
  local files = files_for_revset('@')
  if not files then
    return
  end
  scan_files(files, {}, function() end)
end

--- Scan the current change (@) for todo comments.
function M.todo_current()
  local files = files_for_revset('@')
  if not files then
    return
  end
  scan_files(files, {}, function() end)
end

--- Scan all descendants of a base revision for todo comments.
---@param base string a jj revision
function M.todo_from(base)
  local files = files_descendants(base)
  if not files then
    return
  end
  scan_files(files, {}, function() end)
end

--- Prompt for a base revision and scan its descendants.
function M.todo_descendants()
  vim.ui.input({ prompt = 'Base revision to scan descendants of: ' }, function(base)
    if not base or base == '' then
      return
    end
    M.todo_from(base)
  end)
end

--- Scan only a subset of keyword types, e.g. M.todo_keywords('TODO,FIXME')
function M.todo_keywords(keywords)
  local files = files_for_revset('@')
  if not files then
    return
  end
  scan_files(files, { keywords = keywords }, function() end)
end

vim.api.nvim_create_user_command('JlTodo', M.todo, { desc = 'Scan @ for todos into quickfix' })
vim.api.nvim_create_user_command('JlTodoFrom', function(args)
  M.todo_from(args.args)
end, { nargs = 1, desc = 'Scan descendants of <base> for todos' })
vim.api.nvim_create_user_command('JlTodoDescendants', M.todo_descendants, {
  desc = 'Pick base and scan descendants for todos',
})

vim.keymap.set('n', '<leader>tq', M.todo, { desc = 'TODO [Q]uickfix (working copy)' })
vim.keymap.set('n', '<leader>tQ', M.todo_descendants, { desc = 'TODO quickfix of [D]escendants' })
vim.keymap.set('n', '<leader>jt', function()
  vim.ui.input({ prompt = 'Keywords (e.g. TODO,FIXME,IDEA): ' }, function(kw)
    if kw and kw ~= '' then
      M.todo_keywords(kw)
    end
  end)
end, { desc = '[J]j TODO quickfix by [T]ype' })

return M
