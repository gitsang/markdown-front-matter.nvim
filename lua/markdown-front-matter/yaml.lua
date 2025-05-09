local M = {}

-- Simple YAML parser for front matter
-- Handles basic YAML types needed for front matter: strings, numbers, boolean, arrays

-- Convert Lua table to YAML string
function M.dump(data)
  local result = ""
  
  -- Handle a single table at the top level (as used in the front matter generator)
  if #data == 1 and type(data[1]) == "table" then
    data = data[1]
  end
  
  local function serialize(tbl, indent)
    indent = indent or ""
    local output = {}
    
    for k, v in pairs(tbl) do
      local key = k .. ": "
      
      if type(v) == "table" then
        -- Handle arrays (numeric keys)
        if #v > 0 and type(next(v)) == "number" then
          table.insert(output, indent .. key)
          for _, item in ipairs(v) do
            if type(item) == "string" then
              table.insert(output, indent .. "- \"" .. item:gsub("\"", "\\\"") .. "\"")
            else
              table.insert(output, indent .. "- " .. tostring(item))
            end
          end
        else
          -- Handle nested objects
          table.insert(output, indent .. key)
          local nested = serialize(v, indent .. "  ")
          for _, line in ipairs(nested) do
            table.insert(output, line)
          end
        end
      elseif type(v) == "string" then
        -- Handle strings with proper escaping
        if v:match("[\n:]") or v:match("^%s") or v:match("%s$") then
          -- Multi-line or strings with special characters need quotes
          table.insert(output, indent .. key .. "\"" .. v:gsub("\"", "\\\"") .. "\"")
        else
          table.insert(output, indent .. key .. v)
        end
      elseif type(v) == "boolean" then
        table.insert(output, indent .. key .. tostring(v))
      else
        -- Numbers and other types
        table.insert(output, indent .. key .. tostring(v))
      end
    end
    
    return output
  end
  
  local yaml_lines = serialize(data)
  return table.concat(yaml_lines, "\n")
end

-- Parse YAML string to Lua table
function M.load(yaml_str)
  if not yaml_str or yaml_str == "" then
    return {}
  end
  
  local result = {}
  local lines = {}
  
  -- Split by lines
  for line in yaml_str:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  local current_key = nil
  local current_list = nil
  local indentation_level = 0
  
  for _, line in ipairs(lines) do
    -- Skip empty lines and comments
    if line:match("^%s*$") or line:match("^%s*#") then
      goto continue
    end
    
    -- Handle key-value pairs
    local indent = line:match("^(%s*)")
    local content = line:gsub("^%s*", "")
    
    -- List item
    if content:match("^%- ") then
      local item = content:sub(3)
      
      -- Strip quotes if present
      if item:match('^".*"$') then
        item = item:sub(2, -2):gsub('\\"', '"')
      elseif item:match("^'.*'$") then
        item = item:sub(2, -2):gsub("\\'", "'")
      end
      
      -- Convert to appropriate type
      if item == "true" then item = true
      elseif item == "false" then item = false
      elseif tonumber(item) then item = tonumber(item)
      end
      
      -- Add to current list
      if current_list then
        table.insert(result[current_list], item)
      end
    else
      -- Key-value pair
      local key, value = content:match("^([^:]+):%s*(.*)$")
      if key and key ~= "" then
        current_list = nil
        
        -- Clean up key
        key = key:gsub("^%s*", ""):gsub("%s*$", "")
        
        if value and value ~= "" then
          -- Strip quotes if present
          if value:match('^".*"$') then
            value = value:sub(2, -2):gsub('\\"', '"')
          elseif value:match("^'.*'$") then
            value = value:sub(2, -2):gsub("\\'", "'")
          end
          
          -- Convert to appropriate type
          if value == "true" then value = true
          elseif value == "false" then value = false
          elseif tonumber(value) then value = tonumber(value)
          end
          
          result[key] = value
        else
          -- This could be a list
          result[key] = {}
          current_list = key
        end
      end
    end
    
    ::continue::
  end
  
  return result
end

return M