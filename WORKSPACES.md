# Workspace convention

This config supports per-workspace setups. The goal is:

- **Shared** behavior lives in the global config and loads everywhere.
- **Workspace-specific** behavior lives in its own module and loads only when
  that workspace is detected.
- Maintenance tools (`PackClean`, update checks) know about workspace plugins
  even when the workspace is not active.

The registry lives in `lua/custom/workspaces.lua`. It should contain metadata
only, not feature code.

## Layout

```text
init.lua
lua/custom/
├── workspaces.lua          # profile registry (markers, setup, plugins)
├── pack_clean.lua          # shared maintenance
├── pack_update.lua         # shared maintenance
├── journal.lua             # shared feature
├── shared/                 # optional: code used by 2+ workspaces
│   └── <topic>.lua
├── salesforce/             # a workspace module
│   ├── init.lua            # entrypoint (thin)
│   ├── apex.lua
│   └── blink_soql.lua
├── zig/
│   └── init.lua
└── godot/
    └── init.lua
```

A workspace folder name must match its profile name and be requireable as
`custom.<name>`. Use lowercase, no dots or spaces.

## Rules

1. **The registry is metadata only.** `workspaces.lua` contains markers, the
   setup module, and plugin specs. Feature logic goes in the workspace folder.

2. **One folder per workspace.** `setup` must point to `custom.<name>`, which
   resolves to `lua/custom/<name>/init.lua`.

3. **Workspace-only plugins go in `profile.plugins`.** Do not add them to the
   global `vim.pack.add()` in `init.lua`. This keeps them out of unrelated
   sessions and lets `PackClean`/update checks treat them as known.

4. **Shared plugins stay global.** If two workspaces need the same plugin, keep
   it in the global `vim.pack.add()` instead of duplicating it.

5. **Shared code goes in `lua/custom/shared/`.** If two or more workspaces need
   the same helper, move it there instead of importing one workspace from
   another.

6. **No global side effects from workspace modules.** Keymaps, commands,
   autocmds, LSP config, and options created inside a workspace module should
   only exist when that workspace is loaded. Don't define SF keymaps in the
   global config "just in case".

7. **`init.lua` is a thin entrypoint.** Require submodules by concern as the
   workspace grows:

   ```lua
   -- lua/custom/foo/init.lua
   require 'custom.foo.keymaps'
   require 'custom.foo.lsp'
   require 'custom.foo.commands'
   ```

8. **No environment-specific data in shared code.** Org aliases, absolute
   paths, credentials, and machine-specific commands belong in a project-local
   `.nvim.lua` (see below), not in `lua/custom/`.

9. **Markers are root-level files.** Pick something canonical:
   `sfdx-project.json`, `build.zig`, `project.godot`. If two profiles could
   match the same directory, precedence is controlled by `M.order`.

10. **Start Neovim in the project root.** Detection runs at startup from the
    cwd. Your tmux-per-project workflow already does the right thing. Use
    `:Workspace` to confirm what was detected.

## Adding a new workspace

Checklist:

1. Create the module:

   ```sh
   mkdir -p ~/.config/nvim/lua/custom/foo
   $EDITOR ~/.config/nvim/lua/custom/foo/init.lua
   ```

2. Register it in `lua/custom/workspaces.lua`:

   ```lua
   foo = {
       markers = { 'foo.toml' },
       setup = 'custom.foo',
       plugins = {
           -- workspace-only plugins, if any
           'https://github.com/owner/plugin',
       },
   },
   ```

3. Add `'foo'` to `M.order` in the position that matches your desired
   precedence.

4. Put implementation in the folder and require it from `init.lua`.

5. Verify:

   ```vim
   :Workspace      " shows the profile and root
   :PackUnused     " must not list foo-only plugins
   :PackCheck      " update check must include foo-only plugins
   ```

6. Open Neovim from a directory *without* the marker and confirm the profile is
   not loaded and its keymaps/commands are absent.

## Adding a workspace-only plugin

Add it to that profile's `plugins` list and nowhere else.

```lua
foo = {
    markers = { 'foo.toml' },
    setup = 'custom.foo',
    plugins = {
        'https://github.com/owner/foo.nvim',
    },
},
```

`workspaces.known_plugin_set()` derives the plugin name from the URL basename,
which is also how `vim.pack` names plugins. This is what keeps `PackClean` from
deleting the plugin when you are in a different workspace, and what makes the
automatic update check include it.

If the plugin needs `setup()`, do that inside the workspace module, not in the
global plugin setup section.

## Adding shared code

If a feature is used by two or more workspaces:

1. Move it to `lua/custom/shared/<topic>.lua`.
2. Require it from the workspace modules that need it.
3. Keep it free of workspace-specific assumptions (paths, orgs, markers).

## Project-local settings (optional)

For things that vary per checkout or machine, enable project-local config:

```lua
-- init.lua
vim.o.exrc = true
```

Then add `.nvim.lua` to the project root:

```lua
vim.g.sf_default_org = 'my-org'
```

Neovim only sources these files after you trust them (`:trust`). This is the
right place for paths, org aliases, and local commands. It is not the right
place for code you want to share across projects.

## When global setup needs workspace awareness

Workspace modules are loaded near the end of `init.lua`, so global plugin setup
runs first. If a global setup needs to know the workspace — for example to
register a completion source only for Salesforce — ask the registry instead of
duplicating cwd checks:

```lua
local workspace = require('custom.workspaces').current()
if workspace == 'salesforce' then
    -- global plugin configuration only relevant to Salesforce
end
```

Use this sparingly. Feature code and keymaps must still live in the workspace
module; this is only for plugin configuration that has to happen during the
global setup phase and cannot be moved later.

## Current profiles

| Name | Marker | Setup |
|---|---|---|
| `salesforce` | `sfdx-project.json` | `custom.salesforce` |
| `zig` | `build.zig` | `custom.zig` |
| `godot` | `project.godot` | `custom.godot` |

Profile precedence: `M.order = { 'salesforce', 'zig', 'godot' }`.
