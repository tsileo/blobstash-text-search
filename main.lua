local qry = require('query')
local tknzr = require('tokenizer')

local fields = {'content', 'title'}
local tokenizer = tknzr:new()
local terms = tokenizer:parse(query.qs)

local q = qry:new(terms, fields)

function match(doc)
  q:build_text_index(doc)
  return q:match(doc)
end

return match
