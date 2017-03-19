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

-- Returns the stem of the query term if necessary (using Porter stemmer algorithm)
local function cstem(s)
  -- Detach the prefix (+/-) if any before we stem
  local f = s:sub(1, 1)
  if f == "+" or f == "-" then
    s = s:sub(2, s:len())
  else
    f = ''
  end
  if s:sub(1, 1) == '"' and s:sub(s:len() - 1, 1) == '"' then
    -- If the item is quoted, return it as it.
    return f..s
  end

  -- Lemmatize the word by default
  return f..porterstemmer_stem(s)
end

-- Re-build the terms to join quoted strings (like ['"ok', 'lol"', 'nope'] => ['"ok lol", 'nope']
local function split_qs (qs)
  out = {}
  buf = ''
  in_quote = false
  for _,k in ipairs(qs:split(' ')) do
    -- count the number of double quote (")
    _, count = k:gsub('"', '')
    -- append the current term to the buffer
    buf = buf .. k

    if count == 0 then
      -- no quote
      if in_quote then
        -- if we're inside a quoted string, append a space (to join it)
        buf = buf .. ' '
      else
        -- we're not inside a quoted string, append the term
        _, colon_count = k:gsub(':', '')
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

local tags = {}
tags['tag'] = true
tags['kind'] = true
tags['created'] = true
tags['updated'] = true

function parse_tag(prefix, value)
  -- check if the term is quoted
  quoted = string.sub(value, 1, 1) == '"'

  -- check if term contains a colon (like 'tag:work')
  _, colon_count = value:gsub(':', '')
  contains_colon = colon_count == 1
  tag = ''
  tag_value = ''
  -- extract the tag (and it's value) if it looks there's one
  if not quoted and contains_colon then
    maybe_tag = string.sub(value, 1, string.find(value, ':')-1)
    if tags[maybe_tag] == true then
      tag = maybe_tag
      tag_value = string.sub(value, string.find(value, ':')+1, value:len())
      term = {value=tag_value, prefix=prefix, kind='tag', tag=tag}
      return term
    end
  end

  return nil
end

function parse_query_term(prefix, value)
  -- check if the term is quoted
  quoted = string.sub(value, 1, 1) == '"'

  if value ~= '' then
    if quoted then
      return {value=string.sub(value, 2, value:len() - 1), kind='text_match', prefix=prefix}
    else
      return {value=value, kind='text_stems', prefix=prefix}
    end
  end
  return nil
end

tokenizer = {}
tokenizer.__index = tokenizer

function tokenizer:new()
  local tknzr = {parsers = {parse_query_term}, extra_parsers = {parse_tag}}
  self.__index = self
  return setmetatable(tknzr, self)
end

function tokenizer:add_parser(f)
  table.insert(self.extra_parsers, f)
end

function tokenizer:parse(qs)
  -- Now convert the list of search terms to table
  -- (like ['ok', 'tag:work'] => [{value='ok', kind='text_stems', prefix=''}, {...}]
  terms = {}
  for _, value in ipairs(split_qs(qs)) do
    local prefix = ''
    if string.sub(value, 1, 1) == '+' or string.sub(value, 1, 1) == '-' then
      prefix = string.sub(value, 1, 1)
      value = string.sub(value, 2, value:len())
    end

    local parsed = false
    for _, parsers in ipairs({self.extra_parsers, self.parsers}) do
      if not parsed then
        for _, f in ipairs(parsers) do
          term = f(prefix, value)
          if term ~= nil then
            table.insert(terms, term)
            parsed = true
          end
        end
      end
    end
  end

  return terms
end

return tokenizer
