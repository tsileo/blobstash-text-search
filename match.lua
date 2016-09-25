-- Compute the stems for all the fields
local stems = {}
for ifield,field in ipairs(query.fields) do
  if doc[field] ~= nil then
    stems[field] = porterstemmer(doc[field])
  end
end

-- print('doc=')
-- for key,value in pairs(doc) do
--   print(key, value)
-- end
-- print('/doc')

local ok = true
match = 0

function update_res (ok, prefix, cond)
  if prefix == '+' then
    if cond then match = match + 1 end
    return ok and cond
  end

  if prefix == '-' then
    if not cond then match = match + 1 end
    return ok and not cond
  end

  if cond then match = match + 1 end
  return ok or cond
end

-- Iterate over each query item
for index,value in ipairs(query.qs) do
  -- Determine if the item has a +/- prefix
  local prefix = ''
  if string.sub(value, 1, 1) == '+' or string.sub(value, 1, 1) == '-' then
    prefix = string.sub(value, 1, 1)
    value = string.sub(value, 2, string.len(value))
  end

  if string.sub(value, 1, 1) == '"' then
    -- If the string a quoted, we perform an exact match
    for qfield,field in ipairs(query.fields) do
      if doc[field] ~= nil then
        cond = false
        if string.find(doc[field], string.sub(value, 2, string.len(value) - 1)) ~= nil then
          cond = true
        end
        ok = update_res(ok, prefix, cond)
      end
    end
  else
    -- No quotes, we look for the stems
    for field,cstems in pairs(stems) do
      cond = false
      if cstems[value] ~= nil then
        cond = true
      end
      ok = update_res(ok, prefix, cond)
    end
  end
end

-- Since ok is true at the start, if there's no match, we should return false
if ok and match == 0 then
  return false
end

return ok
