local M = {}
local util = require("markdown-front-matter.util")
local yaml = require("markdown-front-matter.yaml")
local llm = require("markdown-front-matter.llm")

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
  _start_line = 1,
  _end_line = 0,
  _auto_update = true,
};

M.opts = {
  llm = {
    provider = "openai",
    providers = {
      ["openai"] = {
        base_url = "https://api.openai.com/v1",
        api_key = "",
        model = "gpt-3.5-turbo",
      }
    }
  },
  always_update_description = false,  -- Set to true to always update description regardless of existing content
}

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
        if front_matter_start ~= 1 then
          return state -- Return default state if no front matter found
        end
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

    -- YAML Unmarshal using our custom yaml module
    local yaml_content = table.concat(yaml_lines, '\n')
    local success, parsed_data = pcall(yaml.load, yaml_content)  -- Using custom yaml.load

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

  -- Convert the data to YAML format using our custom yaml module
  local yaml_content = yaml.dump({yaml_data})  -- Using custom yaml.dump

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

  return lines
end

function M.update_front_matter_state()
  -- Update front_matter_state
  front_matter_state.slug = util.kebab_case(vim.fn.expand("%:t:r"))

  -- Update date if empty
  vim.notify("[MarkdownFrontMatter] date: " .. front_matter_state.date, vim.log.levels.INFO)
  if front_matter_state.date == "" then
    front_matter_state.date = util.get_iso_time()
  end

  -- Update lastmod
  front_matter_state.lastmod = util.get_iso_time()

  -- Generate description using LLM if description is empty or auto update is enabled
  vim.notify("[MarkdownFrontMatter] description: " .. front_matter_state.description, vim.log.levels.INFO)
  if front_matter_state.description == "" or M.opts.always_update_description then
    vim.notify("[MarkdownFrontMatter] Generating description using LLM", vim.log.levels.INFO)
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")

    -- Remove the front matter to avoid confusing the LLM
    local clean_content = content
    if front_matter_state._end_line > 0 then
      clean_content = table.concat(
        vim.api.nvim_buf_get_lines(0, front_matter_state._end_line, -1, false),
        "\n"
      )
    end

    local description, err = llm.generate_description(clean_content, M.opts)
    vim.notify("[MarkdownFrontMatter] LLM response: " .. (description or "nil"), vim.log.levels.INFO)
    if description then
      front_matter_state.description = description:gsub("\n", " "):gsub("^%s*(.-)%s*$", "%1")
      vim.notify("[MarkdownFrontMatter] Description generated using LLM", vim.log.levels.INFO)
    else
      vim.notify("[MarkdownFrontMatter] Failed to generate description: " .. (err or "unknown error"), vim.log.levels.WARN)
    end
  end
end

function M.write_front_matter()
  local state = M.get_front_matter_state()
  M.update_front_matter_state()
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
