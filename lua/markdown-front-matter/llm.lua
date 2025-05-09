local M = {}

local function call_openai(prompt, opts)
  -- Check if plenary is available
  local has_plenary, curl = pcall(require, 'plenary.curl')
  if not has_plenary then
    return nil, "plenary.nvim is required for HTTP requests"
  end

  -- Prepare the request body
  local body = vim.json.encode({
    model = opts.model,
    messages = {
      {
        role = "user",
        content = prompt
      }
    }
  })

  -- Make the HTTP request
  local response = curl.post(opts.base_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. opts.api_key
    },
    body = body
  })

  -- Check for errors in the response
  if not response or response.status ~= 200 then
    local err_msg = response and response.body or "No response from API"
    return nil, "API request failed: " .. err_msg
  end

  -- Parse the JSON response
  local success, parsed = pcall(vim.json.decode, response.body)
  if not success or not parsed.choices or not parsed.choices[1] then
    return nil, "Failed to parse API response: " .. response.body
  end

  return parsed.choices[1].message.content
end

-- New function to generate all metadata fields
function M.generate_metadata(content, opts)
  if not opts.llm or not opts.llm.provider then
    return nil, "LLM provider not configured"
  end

  local provider = opts.llm.provider
  local provider_opts = opts.llm.providers[provider]

  vim.notify("[MarkdownFrontMatter] Generating metadata using " .. provider .. "/" .. provider_opts.model, vim.log.levels.INFO)

  if not provider_opts then
    return nil, "Selected LLM provider configuration not found"
  end

  -- Create a prompt for the LLM to generate all metadata fields
  local prompt = [[
Based on the following markdown content, please generate ONLY the following metadata in JSON format:
1. title: A concise, descriptive title (1 line)
2. description: A brief summary (1-2 sentences)
3. categories: An array of 1-3 broad categories that the content belongs to
4. tags: An array of 3-7 specific keywords or phrases related to the content

Return ONLY valid JSON in this exact format without explanations, do not include triple backticks (```):
{
  "title": "...",
  "description": "...",
  "categories": ["...", "..."],
  "tags": ["...", "...", "..."]
}

Here's the content:

]] .. content

  local response, err = call_openai(prompt, provider_opts)
  if err or not response then
    return nil, err
  end

  -- Check if the response is wrapped in code blocks and extract it
  local json_str = response
-- Extract JSON from the response, handling markdown code blocks
  local stripped = json_str:gsub("```json%s*", ""):gsub("```%s*$", ""):gsub("```%s*", "")
  -- Further clean up any remaining special characters that might interfere with JSON parsing
  stripped = stripped:gsub("│", ""):gsub("^%s*", ""):gsub("%s*$", "")

  -- Parse the JSON response
  local success, parsed = pcall(vim.json.decode, stripped)
  if not success then
    return nil, "Failed to parse JSON response: " .. stripped
  end

  return parsed
end

return M
