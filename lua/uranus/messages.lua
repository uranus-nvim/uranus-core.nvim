local M = {}

function M.parse(json_str)
  local ok, result = pcall(vim.json.decode, json_str)
  if not ok then
    return nil
  end
  return result
end

function M.serialize(value)
  return vim.json.encode(value)
end

function M.parse_message(json_str)
  local result = M.parse(json_str)
  if not result then
    return nil
  end
  
  return {
    msg_type = result.msg_type or "",
    content = result.content or {},
    metadata = result.metadata or {},
  }
end

function M.is_complete(json_str)
  local count = 0
  for _ in string.gmatch(json_str, "[{}]") do
    count = count + 1
  end
  return count > 0 and count % 2 == 0
end

function M.try_parse_incomplete(json_str)
  if not M.is_complete(json_str) then
    return nil
  end
  return M.parse_message(json_str)
end

return M