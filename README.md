# blobstash-text-search

[![Build Status](https://travis-ci.org/tsileo/blobstash-text-search.svg?branch=master)](https://travis-ci.org/tsileo/blobstash-text-search)

Lua query for [BlobStash](https://github.com/tsileo/blobstash) DocStore that provides a basic full-text search engine.

## Features

 - Support quoted query term for exact match (e.g. "exact match")
 - Support `+`/`-` operator (e.g. `-term` or `+"term query"`)

