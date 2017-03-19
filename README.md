# blobstash_docstore_textsearch

[![Build Status](https://travis-ci.org/tsileo/blobstash_docstore_textsearch.svg?branch=master)](https://travis-ci.org/tsileo/blobstash_docstore_textsearch)

Lua query for [BlobStash](https://github.com/tsileo/blobstash) DocStore that provides a basic full-text search engine.

## Features

 - Text fields are stemmed using Porter stemming algorithm (and query terms)
 - Support quoted query term for exact match (e.g. "exact match")
 - Support `+`/`-` operator (e.g. `-term` or `+"term query"`)

