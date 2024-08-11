# 💪 workspacinator.wezterm

Generates [WezTerm](https://github.com/wez/wezterm)
[workspaces/sessions](https://wezfurlong.org/wezterm/recipes/workspaces.html) on
the fly from your favorite directories, SSH Domains, and currently active
workspaces. All in one *fast fuzzy finder*.

Workspacinator was inspired by using [ThePrimeagen's](https://github.com/ThePrimeagen)
[tmux-sessionizer](https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer)
with [WezTerm](https://github.com/wez/wezterm). I wanted to remove 
[tmux](https://github.com/tmux/tmux) as a dependency (tmux is great), but keep a
similar workflow by taking better advantage of features
that are built in to [WezTerm](https://github.com/wez/wezterm).

## Dependencies

- [find](https://www.gnu.org/software/findutils/manual/html_node/find_html/Invoking-find.html#Invoking-find)

## Features

- List your active workspaces, favorite directories, and ssh domains
in a fuzzy finder.
- Switch to a currently active workspace.
- Create a workspace named after the directory you select, and switch to it.
- Create a workspace named after the domain you select, and connect to the domain.

![workspacinator_demo](https://github.com/user-attachments/assets/569e8b47-f339-4717-a11f-ca215caf11ce)

## Installation

Add the following to your `wezterm.lua`.

```lua
local wezterm = require("wezterm")
local workspacinator = wezterm.plugin.require("https://github.com/eldyl/workspacinator.wezterm") -- require the plugin

local config = wezterm.config_builder() -- Holds our wezterm config

workspacinator.apply_to_config(config, {
  directories = {
    "/", -- Equivalent to "~/" or "$HOME/" in this instance
    -- "/.config",
    -- "/Projects",
  },

  -- ssh_domains = config.ssh_domains, -- Optional

  -- key = "f", -- Default/Optional

  -- mods = "CTRL|ALT", -- Default/Optional

})

return config
```

If you need help, [check out the WezTerm docs](https://wezfurlong.org/wezterm/config/files.html#quick-start)

**Configurable Properties**

- `directories` : string[]
- `ssh_domains` : table[]  
- `key` : string
- `mods` : string

## Usage

### Favorite Directories

- Add directories that hold your projects, or directories that are frequently
navigated to.
- Directories and symbolic links will be listed as valid options, not files.


### Show Current Workspace Status

[A basic example provided in the WezTerm documentation](https://wezfurlong.org/wezterm/config/lua/window/active_workspace.html):
```lua
wezterm.on('update-right-status', function(window, pane)
  window:set_right_status(window:active_workspace())
end)
```

Below is a more elaborate example that shows all directories, and highlights the
currently selected directory:
```lua
wezterm.on("update-right-status", function(window, pane)
  local function get_known_workspaces_el()
    local known_workspaces = wezterm.mux.get_workspace_names()
    local active_workspace = window:active_workspace()
    wezterm.log_info("active_workspace", active_workspace)
    local parsed_workspaces = {}
    for _, workspace in ipairs(known_workspaces) do
      if workspace == active_workspace then
        table.insert(
          parsed_workspaces,
          wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = "#d75f87" } },
            { Text = " " .. workspace .. "*" .. " " },
          })
        )
      else
        table.insert(
          parsed_workspaces,
          wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Text = " " .. workspace .. " " },
          })
        )
      end
    end
    return parsed_workspaces
  end

  window:set_right_status(table.concat(get_known_workspaces_el()))
end)
```

### SSH Domains

- If you decide to use workspacinator to start new SSH connections, make sure
your configuration is passed to the `ssh_domains` table.
- New workspace names, when connecting to an SSH session, are based on the `name`
property of the selected item in your `config.ssh_domains` table.
- New windows may be created if there are confilicting workspace names accross
machines, this can cause unexpected behavior.
- Currently, it is recommended to make sure that your ssh-agent has the proper
credentials available before attempting to connect to a remote machine.

A more complete `~/.config/wezterm/wezterm.lua` example utilizing SSH domains:
```lua
local wezterm = require("wezterm")
local workspacinator = wezterm.plugin.require("https://github.com/eldyl/workspacinator.wezterm")

local config = wezterm.config_builder() -- Holds our wezterm config

  config.ssh_domains = {
    {
      name = "nas",
      remote_address = "192.168.1.1",
      username = "root",
      multiplexing = "None",
    },
    {
      name = "proxmox",
      remote_address = "prox.local.net",
      username = "root",
    },
  }

workspacinator.apply_to_config(config, {
  directories = {
    "/", -- Equivalent to "~/" or "$HOME/" in this instance
    "/.config",
    "/Projects",
  },

  ssh_domains = config.ssh_domains,
})

return config
```

**Same As Above, PLUS full workspace status element**
```lua
local wezterm = require("wezterm")
local workspacinator = wezterm.plugin.require("https://github.com/eldyl/workspacinator.wezterm")

local config = wezterm.config_builder() -- Holds our wezterm config

wezterm.on("update-right-status", function(window, pane)
  local function get_known_workspaces_el()
    local known_workspaces = wezterm.mux.get_workspace_names()
    local active_workspace = window:active_workspace()
    wezterm.log_info("active_workspace", active_workspace)
    local parsed_workspaces = {}
    for _, workspace in ipairs(known_workspaces) do
      if workspace == active_workspace then
        table.insert(
          parsed_workspaces,
          wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = "#d75f87" } },
            { Text = " " .. workspace .. "*" .. " " },
          })
        )
      else
        table.insert(
          parsed_workspaces,
          wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Text = " " .. workspace .. " " },
          })
        )
      end
    end
    return parsed_workspaces
  end

  window:set_right_status(table.concat(get_known_workspaces_el()))
end)

  config.ssh_domains = {
    {
      name = "nas",
      remote_address = "192.168.1.1",
      username = "root",
      multiplexing = "None",
    },
    {
      name = "proxmox",
      remote_address = "prox.local.net",
      username = "root",
    },
  }

workspacinator.apply_to_config(config, {
  directories = {
    "/", -- Equivalent to "~/" or "$HOME/" in this instance
    "/.config",
    "/Projects",
  },

  ssh_domains = config.ssh_domains,
})

return config
```

To learn more about setting SSH Domains in your WezTerm configuration,
[read the WezTerm documentation](https://wezfurlong.org/wezterm/config/lua/SshDomain.html).

## Run Locally

Change to the directory that holds your wezterm configuration. On a UNIX system,
this is likely `~/.config/wezterm/`.

I would do something like this:
```shell
cd ~/.config/wezterm
git clone https://github.com/eldyl/workspacinator.wezterm workspacinator
```

Then I would add the following to my `~/.config/wezterm/wezterm.lua`:
```lua
local workspacinator = require("workspacinator.plugin")

workspacinator.apply_to_config(config, {
  directories = {
    "/", -- Equivalent to "~/" or "$HOME/" in this instance
    -- "/.config",
    -- "/Projects",
  },

  -- ssh_domains = config.ssh_domains, -- Optional

  -- key = "f", -- Default/Optional

  -- mods = "CTRL|ALT", -- Default/Optional

})
```

## Related

- [smart_workspace_switcher.wezterm](https://github.com/MLFlexer/smart_workspace_switcher.wezterm)

## Acknowledgements 

- [WezTerm Docs](https://wezfurlong.org/wezterm/)
- [WezTerm - Workspaces/Sessions](https://wezfurlong.org/wezterm/recipes/workspaces.html)
- [WezTerm - SwitchToWorkspace](https://wezfurlong.org/wezterm/config/lua/keyassignment/SwitchToWorkspace.html)
- [WezTerm - SpawnCommand](https://wezfurlong.org/wezterm/config/lua/SpawnCommand.html)
- [WezTerm - Multiplexing](https://wezfurlong.org/wezterm/multiplexing.html)
- [Commit from Wez](https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd)
