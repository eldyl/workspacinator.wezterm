local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

---@alias action_callback any

local M = {}

---@param str string
---@param sep? string
local function split(str, sep)
  sep = sep or "%s"
  local t = {}
  for field, s in string.gmatch(str, "([^" .. sep .. "]*)(" .. sep .. "?)") do
    table.insert(t, field)
    if s == "" then
      return t
    end
  end
end

---@param user_provided_directories string[]
---@return table workspaces
local function parse_dirs_to_workspaces(user_provided_directories)
  local home = wezterm.home_dir -- Home directory according to wezterm
  local workspaces = {} -- Holds dynamically created workspaces
  local query = { "find" }

  for _, dir in ipairs(user_provided_directories) do
    table.insert(query, home .. dir)
  end

  local additonal_arguments = {
    "-mindepth",
    "1",
    "-maxdepth",
    "1",
    "!",
    "-type",
    "f",
  }

  for _, arg in ipairs(additonal_arguments) do
    table.insert(query, arg)
  end

  local success, stdout, stderr = wezterm.run_child_process(query)

  if success == true then
    local list_of_directories = stdout

    for dir in list_of_directories:gmatch("([^\n]*)(\n?)") do
      table.insert(workspaces, {
        id = dir,
        label = dir,
      })
    end
  else
    wezterm.log_info("Error finding directories", stderr)
  end

  return workspaces
end

---@param directories string[]
---@param ssh_domains? string[]
---@return action_callback
local function use_workspacinator(directories, ssh_domains)
  return wezterm.action_callback(function(window, pane)
    local workspaces = {}
    local active_workspaces = mux.get_workspace_names()
    local filesystem_workspaces = parse_dirs_to_workspaces(directories)

    -- Active Workspaces
    if active_workspaces then
      for _, active in ipairs(active_workspaces) do
        table.insert(workspaces, {
          id = active,
          label = "Active: " .. active,
        })
      end
    end

    -- SSH Domains
    if ssh_domains then
      for _, domain in ipairs(ssh_domains) do
        if domain["multiplexing"] == "None" then
          table.insert(workspaces, {
            id = "SSH: " .. domain["name"],
            label = "SSH: " .. domain["name"],
          })
        else
          table.insert(workspaces, {
            id = "MUX: " .. domain["name"],
            label = "MUX: " .. domain["name"],
          })
        end
      end
    end

    -- Filesystem
    for _, dir in ipairs(filesystem_workspaces) do
      table.insert(workspaces, dir)
    end

    window:perform_action(
      act.InputSelector({
        action = wezterm.action_callback(
          function(inner_window, inner_pane, id, label)
            if id and label then
              if split(label)[1] == "MUX:" or split(label)[1] == "SSH:" then
                label = split(label)[2]

                inner_window:perform_action(
                  act.SwitchToWorkspace({
                    name = label,
                    spawn = {
                      label = "Workspace: " .. label,
                      domain = { DomainName = label },
                    },
                  }),
                  inner_pane
                )
              else
                -- If selecting active_workspace or filesystem_workspaces
                -- Isolate final directory as new workspace name
                for last_directory_in_path in label:gmatch("[^/]+") do
                  label = last_directory_in_path
                end

                -- If Active, trim on selection
                if split(label)[1] == "Active:" then
                  label = split(label)[2]
                end

                inner_window:perform_action(
                  act.SwitchToWorkspace({
                    name = label,
                    spawn = {
                      label = "Workspace: " .. label,
                      cwd = id,
                      domain = "DefaultDomain",
                    },
                  }),
                  inner_pane
                )
              end
            end
          end
        ),
        title = "Workspacinator 💪",
        choices = workspaces,
        fuzzy = true,
        fuzzy_description = wezterm.format({
          { Attribute = { Intensity = "Bold" } },
          { Foreground = { AnsiColor = "Fuchsia" } },
          { Text = "Switch to Workspace -> " },
        }),
      }),
      pane
    )
  end)
end

-- Here we create a function to call our workspacinator module, which we will
-- call in our `wezterm.lua` with our desired configuration
---@param config table
---@param workspacinator_config  { directories: string[], ssh_domains?: string[], key?: string, mods?: string}
function M.apply_to_config(config, workspacinator_config)
  local key = workspacinator_config.key

  local mods = workspacinator_config.mods

  local ssh_domains = workspacinator_config.ssh_domains

  local directories = workspacinator_config.directories

  if not key then
    key = "f"
  end

  if not mods then
    mods = "CTRL|ALT"
  end

  if not config.keys then
    config.keys = {}
  end

  table.insert(config.keys, {
    key = key,
    mods = mods,
    action = use_workspacinator(directories, ssh_domains),
  })
end

return M
