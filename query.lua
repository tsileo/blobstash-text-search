local query = {}
query.__index = query

function match_text_match(term, doc, fields)
  cond = false
  -- If the string a quoted, we perform an exact match
  if term.kind == 'text_match' then
    for qfield,field in ipairs(fields) do
      if doc[field] ~= nil then
        if string.find(doc[field], term.value) ~= nil then
          cond = true
        end
      end
    end
  end
  return cond
end

function match_text_stems(term, doc, fields, stems)
  cond = false
  -- Not a quoted term, we look for the stems
  if term.kind == 'text_stems' then
    for qfield,field in ipairs(fields) do
      if stems[field] ~= nil then
        if stems[field][term.value] == true then
          cond = true
        end
      end
    end
  end
  return cond
end

function query:new(terms, text_fields)
  kind = { text_match = match_text_match, text_stems = match_text_stems }
  local qry = {terms = terms, kind = kind, extra_kind, text_fields = text_fields, stems = {}}
  self.__index = self
  return setmetatable(qry, self)
end

function query:build_text_index(doc)
  -- precompute the stems for all the text fields
  -- FIXME(tsileo): do it only if needed (i.e. if there's at least 1 text search term)
  local stems = {}
  for ifield,field in ipairs(self.text_fields) do
    if doc[field] ~= nil then
      -- TODO(tsileo): ensure doc[field] is a str
      local cstems = porterstemmer(doc[field])
      stems[field] = cstems
    end
  end
  self.stems = stems
end

function query:add_kind(kind, f)
  self.kind[kind] = f
end

function query:match(doc)
  local ok = false

  -- Update the boolean indicating wether the current document matches the query
  -- (called once for each query item, rules depend of the prefix of the query item)
    -- Iterate over each query term
  for _, term in ipairs(self.terms) do
    cond = self.kind[term.kind](term, doc, self.text_fields, self.stems)

    if term.prefix == '+' then
      if not cond then
        return false
      end
    end

    if term.prefix == '-' then
      if cond then
        return false
      end
    end

    if cond then
      ok = true
    end
  end
  return ok
end

return query
