local qry = require('query')
local tknzr = require('tokenizer')

local tokenizer = tknzr:new()
local terms = tokenizer:parse(query.qs)

local q = qry:new(terms, query.fields)

function match(doc)
  q:build_text_index(doc)
  return q:match(doc)
end

return match
