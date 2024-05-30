local wezterm = require("wezterm")
local act = wezterm.action
-- local mux = wezterm.mux

local M = {}

---@alias action_callback any

---@param user_provided_directories string[]
---@return table workspaces
local function turn_directories_into_workspaces(user_provided_directories)
  local home = wezterm.home_dir -- Home directory according to wezterm

  local workspaces = {} -- Holds dynamically created workspaces

  local dirs_with_home_path = {} -- Hold directories with full path

  for _, dir in ipairs(user_provided_directories) do
    -- Insert full paths into table
    table.insert(dirs_with_home_path, home .. dir)
  end

  -- Create string from table to pass to `find`
  local string_of_directories = table.concat(dirs_with_home_path, " ")

  -- Run find process
  local list_of_directories = io.popen(
    "find " .. string_of_directories .. " -mindepth 1 -maxdepth 1 ! -type f"
  )

  -- Iterate through list from find process and insert into workspaces
  if list_of_directories ~= nil then
    for dir in list_of_directories:lines() do
      -- Insert into workspace table
      table.insert(workspaces, {
        id = dir,
        label = dir,
      })
    end
  end
  return workspaces
end

---@param directories table
---@return action_callback
local function use_workspacinator(directories)
  return wezterm.action_callback(function(window, pane)
    -- Create a list of directories to add as potential workspaces
    local workspaces = turn_directories_into_workspaces(directories)

    window:perform_action(
      act.InputSelector({
        action = wezterm.action_callback(
          function(inner_window, inner_pane, id, label)
            if not id and not label then
              wezterm.log_info("cancelled")
            else
              wezterm.log_info("id = " .. id)
              wezterm.log_info("label = " .. label)

              -- Isolate final directory as new workspace name
              for last_directory_in_path in label:gmatch("[^/]+") do
                label = last_directory_in_path
              end

              inner_window:perform_action(
                act.SwitchToWorkspace({
                  name = label,
                  spawn = {
                    label = "Workspace: " .. label,
                    cwd = id,
                  },
                }),
                inner_pane
              )
            end
          end
        ),
        title = "Choose Workspace",
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
---@param workspacinator_config  { directories: string[], key?: string, mods?: string}
function M.apply_to_config(config, workspacinator_config)
  local directories = workspacinator_config.directories

  local key = workspacinator_config.key

  local mods = workspacinator_config.mods

  if not key then
    key = "f"
  end

  if not mods then
    mods = "LEADER"
  end

  table.insert(config.keys, {
    key = key,
    mods = mods,
    action = use_workspacinator(directories),
  })
end

return M
