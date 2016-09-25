-- for index,value in pairs(query) do print(index,value) end
-- local tok = porterstemmer("girls boys, lol, yes it works")
-- if tok[porterstemmer_stem("boy")] ~= nil then
--  print("match")
--  return true
-- end

print('doc=')
for key,value in pairs(doc) do
  print(key, value)
end
print('/doc')

local ok = true

print('iterquery=')
for index,value in ipairs(query) do
  print(index,value)
  local prefix = ''
  if string.sub(value, 1, 1) then
    prefix = string.sub(value, 1, 1)
    value = string.sub(value, 2, string.len(value))
  end
  local b
  if string.sub(value, 1, 1) == '"' then
    b = contains(string.sub(value, 2, string.len(value) - 1), doc.ok)
  else
    -- TODO the porter stemmer thing
  end

  if prefix == '' then
    ok = ok or b
  elseif prefix == '+' then
    ok = ok and b
  elseif preifx == '-' then
    ok = ok and not b
  end
end

return ok

-- local tok = porterstemmer("girls boys, lol, yes it works")
-- if tok[porterstemmer_stem("boy")] ~= nil then
--  print("match")
--  return true
--end
--if doc.ok == 2 then return true else return false end

