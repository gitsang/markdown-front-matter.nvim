local M = {}

-- Function to call OpenAI API
local function call_openai(prompt, opts)
  local curl_cmd = string.format(
    'curl -s -X POST "%s" '..
    '-H "Content-Type: application/json" '..
    '-H "Authorization: Bearer %s" '..
    '-d \'{"model":"%s","messages":[{"role":"user","content":"Hi"}]}\' ',
    opts.base_url,
    opts.api_key,
    opts.model,
    prompt:gsub('"', '\\"'):gsub('\n', '\\n')
  )

  local handle = io.popen(curl_cmd)
  if not handle then
    return nil, "Failed to execute curl command"
  end

  local result = handle:read("*a")
  handle:close()

  local success, response = pcall(vim.json.decode, result)
  if not success or not response.choices or not response.choices[1] then
    return nil, "Failed to parse API response: " .. result
  end

  return response.choices[1].message.content
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

Return ONLY valid JSON in this exact format without explanations:
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

  -- Extract JSON from the response (in case the LLM returns additional text)
  local json_str = response:match("{.-}%s*$") or response
  -- Parse the JSON response
  local success, parsed = pcall(vim.json.decode, json_str)
  if not success then
    return nil, "Failed to parse JSON response: " .. json_str
  end

  return parsed
end

return M
