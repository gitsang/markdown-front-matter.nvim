local M = {}

-- Function to call OpenAI API
local function call_openai(prompt, opts)
  local curl_cmd = string.format(
    'curl -s -X POST "%s" '..
    '-H "Content-Type: application/json" '..
    '-H "Authorization: Bearer %s" '..
    '-d \'{"model":"%s","messages":[{"role":"user","content":"%s"}],"temperature":0.7}\' ',
    opts.base_url,
    opts.api_key,
    opts.model,
    prompt:gsub('"', '\\"')
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

-- Function to get description using configured LLM
function M.generate_description(content, opts)
  if not opts.llm or not opts.llm.provider then
    return nil, "LLM provider not configured"
  end

  local provider = opts.llm.provider
  local provider_opts = opts.llm.providers[provider]

  vim.notify("[MarkdownFrontMatter] Generating description using " .. provider .. "/" .. provider_opts.model, vim.log.levels.INFO)

  if not provider_opts then
    return nil, "Selected LLM provider configuration not found"
  end

  -- Create a prompt for the LLM to generate a description
  local prompt = "Please generate a short description (1-2 sentences) of the following markdown content:\n\n" .. content

  return call_openai(prompt, provider_opts)
end

return M
