local M = {}

function M.kebab_case(filename)
  return filename:lower()
    :gsub("%s+", "-")
    :gsub("_", "-")
    :gsub("[^%w-]", "")
    :gsub("-+", "-")
    :gsub("^%-", "")
    :gsub("%-$", "")
end

function M.get_iso_time()
  local time = os.date("*t")
  return string.format("%04d-%02d-%02dT%02d:%02d:%02d+08:00",
    time.year, time.month, time.day, time.hour, time.min, time.sec)
end

return M
