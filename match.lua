-- for index,value in pairs(query) do print(index,value) end
-- local tok = porterstemmer("girls boys, lol, yes it works")
-- if tok[porterstemmer_stem("boy")] ~= nil then
--  print("match")
--  return true
-- end
local stems = {}
for ifield,field in ipairs(query.fields) do
  if doc[field] ~= nil then
    stems[field] = porterstemmer(doc[field])
  end
end


print('doc=')
for key,value in pairs(doc) do
  print(key, value)
end
print('/doc')

local ok = true
match = 0


function update_res (ok, prefix, cond)
  print('update_res')
  print(ok)
  print(prefix)
  print(cond)
  print('/')
  if prefix == '+' then
    if cond then match = match + 1 end
    print('prefix+')
    print(ok and cond)
    return ok and cond
  end

  if prefix == '-' then
    if not cond then match = match + 1 end
    print('prefix-')
    print(ok and not cond)
    return ok and not cond
  end

  print('default')
  if cond then match = match + 1 end
  print(ok or cond)
  return ok or cond
end

print('iterquery=')
for index,value in ipairs(query.qs) do
  print(index,value)
  local prefix = ''
  if string.sub(value, 1, 1) == '+' or string.sub(value, 1, 1) == '-' then
    prefix = string.sub(value, 1, 1)
    value = string.sub(value, 2, string.len(value))
  end
  if string.sub(value, 1, 1) == '"' then
    for qfield,field in ipairs(query.fields) do
      if doc[field] ~= nil then
        cond = false
        if string.find(doc[field], string.sub(value, 2, string.len(value) - 1)) ~= nil then
          cond = true
        end
        print('/')
        print(field)
        print(value)
        print(cond)
        print('/')
        ok = update_res(ok, prefix, cond)
      end
    end
  else
    -- TODO the porter stemmer thing
    for field,cstems in pairs(stems) do
      cond = false
      if cstems[value] ~= nil then
        cond = true
      end
      print('/stem')
      print(field)
      print(value)
      print(cond)
      print('/stem')
      ok = update_res(ok, prefix, cond)
    end
  end
end

if ok and match == 0 then
  return false
end

return ok

-- local tok = porterstemmer("girls boys, lol, yes it works")
-- if tok[porterstemmer_stem("boy")] ~= nil then
--  print("match")
--  return true
--end
--if doc.ok == 2 then return true else return false end

