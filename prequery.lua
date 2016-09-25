-- local s = '+okok -llol "nope lol" "loool  lol ll topnope" is:archived'
function cstem (s)
  local f = string.sub(s, 1, 1)
  if f == "+" or f == "-" then
    s = string.sub(s, 2, string.len(s))
  else
    f = ''
  end
  if string.sub(s, 1, 1) == '"' and string.sub(s, string.len(s) - 1, 1) == '"' then
    return f..porterstemmer_stem(s)
  end
  return f..s
end
function split_qs (s)
local start = 0
local out = ''
local quoted = false

local t = {}                   -- table to store the indices
    local i = 0
    while true do
      -- for index,value in ipairs(t) do print(index,value) end
      i = string.find(s, " ", start)    -- find 'next' newline
      if i == nil then
          if string.len(s) - start > 0 then
             table.insert(t, cstem(string.sub(s, start, string.len(s))))
          end
          break
      end
      local sub = string.sub(s, start, i)
      local cquote = false
      if string.find(sub, '"', 0) then cquote = true end
        if sub ~= " " then
          if cquote then
            if quoted then
              out = out..sub
              table.insert(t, cstem(out))
              quoted = false
              out = ''
            else
               quoted = true
               out = out..sub
            end
          else
            if quoted then
              out = out..sub
            else
              table.insert(t, cstem(sub))
            end
          end
        end
      start = i+1
    end
 -- for index,value in ipairs(t) do print(index,value) end
if out ~= "" then
  table.insert(t, cstem(out))
end
return t
end
return split_qs(query)

-- keywords2 = keywords.match(/[-\+\:\w]+|["|'](?:\\"|[^i"])+['"]/g);
-- ["okok", "+ok", "-yes", ""ook okokko k"", "'okok  lol'", "is:archived"]


