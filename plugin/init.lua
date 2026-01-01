local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

---@alias action_callback any

local M = {}

local HOME = wezterm.home_dir -- User home directory

local FUZZY_DESCRIPTION = wezterm.format({
  { Attribute = { Intensity = "Bold" } },
  { Foreground = { AnsiColor = "Fuchsia" } },
  { Text = "Switch to Workspace -> " },
})

---Splits a string on whitespace and returns the resulting table.
---@param str string
---@return string[]
local function split_whitespace(str)
  local t = {}
  for field in string.gmatch(str, "%S+") do
    t[#t + 1] = field
  end
  return t
end

---@param user_provided_directories string[]
---@return table workspaces
local function parse_dirs_to_workspaces(user_provided_directories)
  if not user_provided_directories then
    return {}
  end

  local workspaces = {} -- Holds dynamically created workspaces
  local query = { "find" }

  for _, dir in ipairs(user_provided_directories) do
    query[#query + 1] = HOME .. dir
  end

  local additonal_arguments = {
    "-mindepth",
    "1",
    "-maxdepth",
    "1",
    "(",
    "-type",
    "d",
    "-o",
    "(",
    "-type",
    "l",
    "-xtype",
    "d",
    ")",
    ")",
  }

  for _, arg in ipairs(additonal_arguments) do
    query[#query + 1] = arg
  end

  local ok, stdout, stderr = wezterm.run_child_process(query)
  if ok then
    -- Match one or more characters that aren't newlines
    for dir in stdout:gmatch("[^\n]+") do
      workspaces[#workspaces + 1] = {
        id = dir,
        label = dir,
      }
    end
  else
    wezterm.log_error("Error calling `find` on provided directories", stderr)
  end

  return workspaces
end

local function handle_workspace_selection(inner_window, inner_pane, id, label)
  if not (id and label) then
    return
  end

  local parts = split_whitespace(label)
  local prefix = parts[1]

  if prefix == "MUX:" or prefix == "SSH:" then
    label = parts[2]

    return inner_window:perform_action(
      act.SwitchToWorkspace({
        name = label,
        spawn = {
          label = "Workspace: " .. label,
          domain = { DomainName = label },
        },
      }),
      inner_pane
    )
  end

  -- If selecting active_workspace or filesystem_workspaces
  -- Isolate final directory as new workspace name
  label = label:match("([^/]+)$") or label

  -- If Active, trim on selection
  if prefix == "Active:" then
    label = parts[2]
  end

  return inner_window:perform_action(
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

---@param directories string[]
---@param ssh_domains? table[]
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
        action = wezterm.action_callback(handle_workspace_selection),
        title = "Workspacinator 💪",
        choices = workspaces,
        fuzzy = true,
        fuzzy_description = FUZZY_DESCRIPTION,
      }),
      pane
    )
  end)
end

---Here we create a function to call our workspacinator module, which we will
---call in our `wezterm.lua` with our desired configuration.
---@param config table
---@param workspacinator_config  { directories: string[], ssh_domains?: table[], key?: string, mods?: string}
function M.apply_to_config(config, workspacinator_config)
  local directories = workspacinator_config.directories
  local ssh_domains = workspacinator_config.ssh_domains
  local key = workspacinator_config.key or "f"
  local mods = workspacinator_config.mods or "CTRL|ALT"

  config.keys = config.keys or {}

  config.keys[#config.keys + 1] = {
    key = key,
    mods = mods,
    action = use_workspacinator(directories, ssh_domains),
  }
end

return M
