local M = {}

local function kebab_case(filename)
  return filename:lower()
    :gsub("%s+", "-")
    :gsub("_", "-")
    :gsub("[^%w-]", "")
    :gsub("-+", "-")
    :gsub("^%-", "")
    :gsub("%-$", "")
end

local function get_iso_time()
  local time = os.date("*t")
  return string.format("%04d-%02d-%02dT%02d:%02d:%02d+08:00",
    time.year, time.month, time.day, time.hour, time.min, time.sec)
end

function M.insert_frontmatter()
  local bufname = vim.api.nvim_buf_get_name(0)
  local filename = vim.fn.fnamemodify(bufname, ":t:r")
  local slug = kebab_case(filename)
  
  local datetime = get_iso_time()
  
  local frontmatter = {
    "---",
    string.format('title: ""'),
    string.format('slug: "%s"', slug),
    'description: ""',
    string.format('date: "%s"', datetime),
    string.format('lastmod: "%s"', datetime),
    'weight: 1',
    'categories:',
    'tags:',
    "---",
    ""
  }
  
  vim.api.nvim_buf_set_lines(0, 0, 0, false, frontmatter)
end

local function setup()
  vim.api.nvim_create_user_command("MarkdownFrontMatterInit", function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, 1, false)
    if #lines > 0 and lines[1]:match("^%-%-%-") then
      print("Front Matter already exists")
      return
    end
    
    M.insert_frontmatter()
  end, {})
end

return {
  setup = setup
}
