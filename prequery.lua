-- Returns the stem of the query term if necessary (using Porter stemmer algorithm)
local tags = {tag=true, ['type']=true}

-- debug function
function debug (msg, ...)
  if debug then
    print(string.format(msg, unpack(arg)))
  end
end

-- Python-like string.split implementation http://lua-users.org/wiki/SplitJoin
function string:split(sSeparator, nMax, bRegexp)
   assert(sSeparator ~= '')
   assert(nMax == nil or nMax >= 1)

   local aRecord = {}

   if self:len() > 0 then
      local bPlain = not bRegexp
      nMax = nMax or -1

      local nField, nStart = 1, 1
      local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
      while nFirst and nMax ~= 0 do
         aRecord[nField] = self:sub(nStart, nFirst-1)
         nField = nField+1
         nStart = nLast+1
         nFirst,nLast = self:find(sSeparator, nStart, bPlain)
         nMax = nMax-1
      end
      aRecord[nField] = self:sub(nStart)
   end

   return aRecord
end

function cstem (s)
  -- Detach the prefix (+/-) if any before we stem
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

-- Re-build the terms to join quoted strings (like ['"ok', 'lol"', 'nope'] => ['"ok lol", 'nope']
function split_qs (qs)
  out = {}
  buf = ''
  in_quote = false
  for _,k in ipairs(string.split(qs, ' ')) do
    -- count the number of double quote (")
    _, count = string.gsub(k, '"', '')
    -- append the current term to the buffer
    buf = buf .. k

    if count == 0 then
      -- no quote
      if in_quote then
        -- if we're inside a quoted string, append a space (to join it)
        buf = buf .. ' '
      else
        -- we're not inside a quoted string, append the term
        _, colon_count = string.gsub(k, ':', '')
        if colon_count == 0 then
          -- the term does not contain a colon (no modifier like tag:work),
          -- it's a search term, we can stem it
          table.insert(out, cstem(buf))
        else
          table.insert(out, buf)
        end
        -- and reset the buffer
        buf = ''
      end
    elseif count == 1 then
      -- 1 quote
      if in_quote then
        -- it's the end of a quoted string
        table.insert(out, buf)
        -- reset the buffer and the "quote state"
        buf = ''
        in_quote = false
      else
        -- it's the start of a quoted term
        in_quote = true
        -- join the term
        buf = buf .. ' '
      end
    elseif count == 2 and not in_quote then
      -- 2 quote, it's a self contained quoted term (like '"term"')
      table.insert(out, buf)
      -- reset the buffer
      buf = ''
    end
  end

  return out
end

-- Now convert the list of search terms to table
-- (like ['ok', 'tag:work'] => [{value='ok', kind='text_stems', prefix=''}, {...}]
terms = {}
for _, value in ipairs(split_qs(query.qs)) do
  local prefix = ''
  if string.sub(value, 1, 1) == '+' or string.sub(value, 1, 1) == '-' then
    prefix = string.sub(value, 1, 1)
    value = string.sub(value, 2, string.len(value))
  end

  -- check if the term is quoted
  quoted = string.sub(value, 1, 1) == '"'

  -- check if term contains a colon (like 'tag:work')
  _, colon_count = string.gsub(value, ':', '')
  contains_colon = colon_count == 1
  tag = ''
  tag_value = ''
  -- extract the tag (and it's value) if it looks there's one
  if contains_colon then
    maybe_tag = string.sub(value, 1, string.find(value, ':')-1)
    if tags[maybe_tag] == true then
      tag = maybe_tag
      tag_value = string.sub(value, string.find(value, ':')+1, string.len(value))
    end
  end

  if value ~= '' then
    if quoted then
      table.insert(terms, {value=string.sub(value, 2, string.len(value) - 1), kind='text_match', prefix=prefix})
    elseif not quoted and tag ~= '' then
      table.insert(terms, {value=tag_value, kind='tag', tag=tag, prefix=prefix})
    else
      table.insert(terms, {value=value, kind='text_stems', prefix=prefix})
    end
  end
end

return {terms=terms}
