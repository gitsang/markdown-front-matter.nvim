local M = {}
local util = require("markdown-front-matter.util")
local yaml = require("markdown-front-matter.yaml")
local llm = require("markdown-front-matter.llm")

local front_matter_flag = "<!-- markdown-front-matter -->"
local front_matter_state = {};

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

function M.load_front_matter_state()
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Initialize front_matter_state with default values
  front_matter_state = {
    title = "",
    slug = "",
    description = "",
    date = "",
    lastmod = "",
    weight = 1,
    categories = {},
    tags = {},
    _flag_line = 0,
  }

  -- Find front matter boundaries
  for i, line in ipairs(content) do
    if line == front_matter_flag then
      vim.notify("Found front matter flag at line " .. i, vim.log.levels.INFO)
      front_matter_state._flag_line = i
      break
    end
  end
  if front_matter_state._flag_line == 0 then
    return
  end

  -- Extract YAML content
  local yaml_lines = {}

  for i = 1, front_matter_state._flag_line - 3 do
    local line = content[i]
    if not line:match(front_matter_flag) then
      table.insert(yaml_lines, line)
    end
  end

  -- YAML Unmarshal using our custom yaml module
  local yaml_content = table.concat(yaml_lines, '\n')
  local success, parsed_data = pcall(yaml.load, yaml_content)  -- Using custom yaml.load

  if success and parsed_data then
    -- Merge parsed data into state
    for k, v in pairs(parsed_data) do
      front_matter_state[k] = v
    end
  else
    vim.notify("YAML parsing error, using default values", vim.log.levels.WARN)
  end
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

  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, front_matter_flag)

  return lines
end

function M.update_front_matter_state()
  front_matter_state.slug = util.kebab_case(vim.fn.expand("%:t:r"))

  if front_matter_state.date == "" or type(front_matter_state.date) == "table" then
    front_matter_state.date = util.get_iso_time()
  end
  front_matter_state.lastmod = util.get_iso_time()

  -- Get categories from parent directory name
  local parent_dir = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h:t")
  if parent_dir ~= "" then
    front_matter_state.categories = {parent_dir}
  end

  -- Generate metadata using LLM
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local clean_content = content
  if front_matter_state._flag_line > 0 then
    clean_content = table.concat(
      vim.api.nvim_buf_get_lines(0, front_matter_state._flag_line, -1, false),
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
    if front_matter_state.tags == {} or type(front_matter_state.tags) == "table" then
      front_matter_state.tags = metadata.tags
    end
  end
end

function M.write_front_matter()
  M.load_front_matter_state()
  M.update_front_matter_state()
  local lines = M.generate_front_matter_content()
  vim.api.nvim_buf_set_lines(0, 0, front_matter_state._flag_line, false, lines)
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
