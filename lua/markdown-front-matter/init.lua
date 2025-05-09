local M = {}
local util = require("markdown-front-matter.util")
local yaml = require('plenary.filetype.yaml')

local auto_update_flag = "<!-- markdown-front-matter auto -->"
local front_matter_state = {
  title = "",
  slug = "",
  description = "",
  date = "",
  lastmod = "",
  weight = 1,
  categories = {},
  tags = {},
  _start_line = 0,
  _end_line = 0,
  _auto_update = true,
};

function M.get_front_matter_state()
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Initialize front_matter_state with default values
  local state = front_matter_state

  -- Find front matter boundaries
  local front_matter_start = nil
  local front_matter_end = nil
  for i, line in ipairs(content) do
    if line:match("^%-%-%-") then
      if front_matter_start == nil then
        front_matter_start = i
      else
        front_matter_end = i
        break
      end
    end
  end

  -- If boundaries are found
  if front_matter_start and front_matter_end and front_matter_end > front_matter_start then
    -- Update boundary information
    state._start_line = front_matter_start
    state._end_line = front_matter_end

    -- Extract YAML content
    local yaml_lines = {}

    for i = front_matter_start + 1, front_matter_end - 1 do
      local line = content[i]
      -- Check for auto update flag
      if line:match(auto_update_flag) then
        state._auto_update = true
      else
        table.insert(yaml_lines, line)
      end
    end

    -- YAML Unmarshal
    local yaml_content = table.concat(yaml_lines, '\n')
    local success, parsed_data = pcall(yaml.parse, yaml_content)

    if success and parsed_data then
      -- Merge parsed data into state
      for k, v in pairs(parsed_data) do
        state[k] = v
      end
      return state
    else
      vim.notify("YAML parsing error, using default values", vim.log.levels.WARN)
      return state
    end
  end

  return state -- Return default state if no front matter found
end

function M.generate_front_matter_content()
  -- Create a copy of front_matter_state without the `_` prefix field
  local yaml_data = {}
  for k, v in pairs(front_matter_state) do
    if not k:match("^_") then
      yaml_data[k] = v
    end
  end

  -- Convert the data to YAML format using plenary
  local yaml_content = yaml.stringify(yaml_data)

  -- Create the front matter with delimiters
  local lines = {"---"}

  -- Add yaml content, splitting by newlines
  for line in string.gmatch(yaml_content, "[^\r\n]+") do
    table.insert(lines, line)
  end

  -- Add auto update flag if needed
  if front_matter_state["_auto_update"] then
    table.insert(lines, "")
    table.insert(lines, auto_update_flag)
  end

  table.insert(lines, "---")
  table.insert(lines, "")

  return lines
end

function M.write_front_matter()
  local state = M.get_front_matter_state()
  local lines = M.generate_front_matter_content()
  vim.api.nvim_buf_set_lines(0, state._start_line - 1, state._end_line, false, lines)
  vim.notify("[MarkdownFrontMatter] Front matter updated", vim.log.levels.INFO)
end

local function setup()
  vim.api.nvim_create_user_command("MarkdownFrontMatter", function()
    M.write_front_matter()
  end, {})
end

return {
  setup = setup
}
