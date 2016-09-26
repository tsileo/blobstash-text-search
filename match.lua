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

-- Update the boolean indicating wether the current document matches the query
-- (called once for each query item, rules depend of the prefix of the query item)
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

  -- Check the current query item against each field, and OR the results for each field before updating the res
  cond = false
  for qfield,field in ipairs(query.fields) do
    -- Check if the current document contains the field
    if doc[field] ~= nil then
      if string.sub(value, 1, 1) == '"' then
        -- If the string a quoted, we perform an exact match
        if string.find(doc[field], string.sub(value, 2, string.len(value) - 1)) ~= nil then
          cond = cond or true
        end
      else
        -- No quotes, we look for the stems
        if stems[field][value] ~= nil then
          cond = cond or true
        end
      end
    end
  end
  ok = update_res(ok, prefix, cond)
end

-- Since ok is true at the start, if there's no match, we should return false
if ok and match == 0 then
  return false
end

return ok
