-- local s = '+okok -llol "nope lol" "loool  lol ll topnope" is:archived'
function cstem (s)
  local f = string.sub(s, 1, 1)
  if f == "+" or f == "-" then
    s = string.sub(s, 2, string.len(s))
  else
    f = ''
  end
  if string.sub(s, 1, 1) == '"' and string.sub(s, string.len(s) - 1, 1) == '"' then
    -- If the item is quoted, return it as it.
    return f..s
  end

  -- Lemmatize the word by default
  return f..porterstemmer_stem(s)
end

function split_qs (s)
  local start = 0
  local out = ''
  local quoted = false

  local t = {}                   -- table to store the indices
  local i = 0

  while true do
    -- for index,value in ipairs(t) do print(index,value) end
    i = string.find(s, " ", start)    -- find 'next' separator
    if i == nil then
      if string.len(s) - start > 0 then
        -- Insert the whole end of the string
        table.insert(t, cstem(string.sub(s, start, string.len(s))))
      end
      break
    end

    -- Get the substring till the next space
    local sub = string.sub(s, start, i)

    -- Check if the substring is quoted
    local cquote = false
    if string.find(sub, '"', 0) then
      cquote = true
    end

    if sub ~= " " then
      if cquote then
        -- The substring start with a quote
        if quoted then
          -- And there's an incomplete quoted string buffer
          out = out..sub
          -- We can complete it and reset the quote state
          table.insert(t, cstem(out))
          quoted = false
          out = ''
        else
           -- Start a quote buffer
           quoted = true
           out = out..sub
        end
      else
        if quoted then
          -- We're still inside a quoted item, add the substring to the buffer
          out = out..sub
        else
          -- It's a normal query item, add it to the list
          table.insert(t, cstem(sub))
        end
      end
    end
    start = i+1
  end
   -- for index,value in ipairs(t) do print(index,value) end
  if out ~= "" then
    -- There still some data in the buffer, append it to the query (unquoted data?)
    table.insert(t, cstem(out))
  end
  return t
end
print(query)
return {qs = split_qs(query.qs), fields = query.fields}

-- keywords2 = keywords.match(/[-\+\:\w]+|["|'](?:\\"|[^i"])+['"]/g);
-- ["okok", "+ok", "-yes", ""ook okokko k"", "'okok  lol'", "is:archived"]
