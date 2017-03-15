-- Compute the stems for all the fields
local fields = {'content', 'title'}
local tags = {tag=true, ['type']=true}

function debug(msg, ...)
  if debug then
    print(string.format(msg, unpack(arg)))
  end
end
debug('')
debug('debug enabled, %s', #doc)

-- precompute the stems for all the text fields
-- FIXME(tsileo): do it only if needed (i.e. if there's a text search term)
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
debug('doc=%s, %s', doc, doc['tags'])
if doc['tags'] ~= nil then
  for _,tag in ipairs(doc['tags']) do
    debug('init tag=%s', tag)
    tags_index[tag] = true
  end
end

-- TODO(tsileo): archived:false by default
-- TODO(tsileo): FS black hole for blobs project
-- TODO(tsileo): near:lat,long query

-- TODO(tsileo): tags query
-- tag:work
-- -tag:perso

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

-- Iterate over each query item
for index,value in ipairs(query.qs) do  -- TODO s/value/term/
  -- Determine if the item has a +/- prefix
  local prefix = ''
  if string.sub(value, 1, 1) == '+' or string.sub(value, 1, 1) == '-' then
    prefix = string.sub(value, 1, 1)
    value = string.sub(value, 2, string.len(value))
  end
  debug('query item index=%i value=%s', index, value)

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
  debug('tag_value=%s', tag_value)

  -- Check the current query item against each field, and OR the results for each field
  -- before updating the res
  cond = false

  if tag ~= '' then
    -- The term contains a tag
    if tag == 'tag' then

      -- check if the tag (as in tagging, the "query tag" value) is in the index
      if tags_index[tag_value] == true then
        cond = cond or true
      end

    end
  else
    -- This is a text search, iterate over each text field
    for qfield,field in ipairs(fields) do
      debug('field[%i]=%s, value=%s, cond=%s', qfield, field, doc[field], cond)
      -- Check if the current document contains the field
      if doc[field] ~= nil then

        -- If the string a quoted, we perform an exact match
        if quoted and string.find(doc[field], string.sub(value, 2, string.len(value) - 1)) ~= nil then
          cond = cond or true
        end

        -- Not a quoted term, we look for the stems
        if not quoted and stems[field][value] == true then
          cond = cond or true
        end

      end
    end
  end

  -- Update `ok`
  ok, bigno = update_res(ok, prefix, cond)
  -- if there's a big no (i.e. a matching "-term" or non-matching "+term" triggered it)
  if bigno then
    return false
  end
end

return ok
