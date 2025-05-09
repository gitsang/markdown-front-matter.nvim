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
  -- Define the order of fields
  local field_order = {
    "title",
    "slug",
    "description",
    "date",
    "lastmod",
    "weight",
    "categories",
    "tags"
  }

  -- Create the front matter with delimiters
  local lines = {"---"}

  -- Add fields in the specified order
  for _, key in ipairs(field_order) do
    local value = front_matter_state[key]
    if value ~= nil then
      -- Let the YAML module handle individual field serialization
      local field_yaml = yaml.dump({[key] = value})
      -- Remove the document start/end markers from the field yaml
      field_yaml = field_yaml:gsub("^%-%-%-\n", ""):gsub("\n%.%.%.$", "")

      -- Split the field_yaml by newlines and add each line
      for line in field_yaml:gmatch("[^\r\n]+") do
        table.insert(lines, line)
      end
    end
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
  front_matter_state.slug = util.kebab_case(vim.fn.expand("%:t:r"))

  if front_matter_state.date == "" or type(front_matter_state.date) == "table" then
    front_matter_state.date = util.get_iso_time()
  end
  front_matter_state.lastmod = util.get_iso_time()

  -- Generate metadata using LLM
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local clean_content = content
  if front_matter_state._end_line > 0 then
    clean_content = table.concat(
      vim.api.nvim_buf_get_lines(0, front_matter_state._end_line, -1, false),
      "\n"
    )
  end
  local metadata, err = llm.generate_metadata(clean_content, M.opts)
  if metadata == nil or err ~= nil then
    vim.notify("[MarkdownFrontMatter] Failed to generate metadata: " .. err, vim.log.levels.ERROR)
  else
    if front_matter_state.title == "" or type(front_matter_state.title) == "table" then
      front_matter_state.title = metadata.title:gsub("\n", " "):gsub("^%s*(.-)%s*$", "%1")
    end
    if front_matter_state.description == "" or type(front_matter_state.description) == "table" then
      front_matter_state.description = metadata.description:gsub("\n", " "):gsub("^%s*(.-)%s*$", "%1")
    end
    if front_matter_state.categories == {} or type(front_matter_state.categories) == "table" then
      front_matter_state.categories = metadata.categories
    end
    if front_matter_state.tags == {} or type(front_matter_state.tags) == "table" then
      front_matter_state.tags = metadata.tags
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

function M.setup(opts)
  -- Merge user options with defaults
  if opts then
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)
  end

  vim.api.nvim_create_user_command("MarkdownFrontMatter", function()
    M.write_front_matter()
  end, {})
end

return {
  setup = M.setup
}
