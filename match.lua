-- Compute the stems for all the fields
local fields = {'content', 'title'}

function debug(msg, ...)
  if debug then
    print(string.format(msg, unpack(arg)))
  end
end

-- precompute the stems for all the text fields
-- FIXME(tsileo): do it only if needed (i.e. if there's at least 1 text search term)
local stems = {}
for ifield,field in ipairs(fields) do
  if doc[field] ~= nil then
    -- TODO(tsileo): ensure doc[field] is a str
    local cstems = porterstemmer(doc[field])
    stems[field] = cstems
  end
end

-- build the tags index of the doc
local tags_index = {}
if doc['tags'] ~= nil then
  for _,tag in ipairs(doc['tags']) do
    tags_index[tag] = true
  end
end

-- TODO(tsileo): archived:false by default
-- TODO(tsileo): FS black hole for blobs project
-- TODO(tsileo): near:lat,long query

-- TODO(tsileo): support date query, like:
-- created:2016
-- updated:2017-01-23T20
-- created:>2016 created:<2017
-- -created:2016

-- TODO(tsileo): support type query, like:
-- type:note
-- type:file
-- -type:file

local ok = false
-- match = 0

-- Update the boolean indicating wether the current document matches the query
-- (called once for each query item, rules depend of the prefix of the query item)
function update_res (ok, prefix, cond)
  if prefix == '+' then
    return ok and cond, not cond
  end

  if prefix == '-' then
    return ok and not cond, cond
  end

  return ok or cond, false
end

-- Iterate over each query term
for index, term in ipairs(query.terms) do
  cond = false

  -- The term contains a tag
  if term.kind == 'tag' then

    if term.tag == 'tag' then
      -- check if the tag (as in tagging, the "query tag" value) is in the index
      if tags_index[term.value] == true then
        cond = cond or true
      end
    end

    if term.tag == 'kind' then
      if doc['kind'] == term.value then
        cond = cond or true
      end
    end

    if term.tag == 'created' or term.tag == 'updated' then
      date = doc[term.tag]
      -- If there's no updated field, set created instead
      if term.tag == 'updated' and doc['updated'] == nil then
        date = doc['created']
      end

      -- Check if there's a ">" or "<" modifier
      value = term.value
      prefix = ''
      test_prefix = term.value:sub(1, 2)
      if test_prefix == '>' or test_prefix == '<' then
        value = value:sub(2, value:len())
        prefix = test_prefix
      end

      if value == date:sub(1, value:len()) then
        cond = cond or true
      end
      -- FIXME handle >/< modifiers

    end

  end

  -- The term is a text search
  if term.kind == 'text_match' or term.kind == 'text_stems' then
    -- This is a text search, iterate over each text field
    for qfield,field in ipairs(fields) do
      -- Check if the current document contains the field
      if doc[field] ~= nil then

        -- If the string a quoted, we perform an exact match
        if term.kind == 'text_match' and string.find(doc[field], term.value) ~= nil then
          cond = cond or true
        end

        -- Not a quoted term, we look for the stems
        if term.kind == 'text_stems' and stems[field][term.value] == true then
          cond = cond or true
        end

      end
    end
  end

  -- Update `ok`
  ok, bigno = update_res(ok, term.prefix, cond)
  -- if there's a big no (i.e. a matching "-term" or non-matching "+term" triggered it)
  if bigno then
    return false
  end
end

return ok
