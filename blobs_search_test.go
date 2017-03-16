package main

import (
	"bytes"
	"reflect"
	"testing"

	luautil "a4.io/blobstash/pkg/apps/luautil"
	"github.com/blevesearch/segment"
	"github.com/reiver/go-porterstemmer"
	"github.com/yuin/gopher-lua"
)

// copy-pasted from BlobStash
func stem(L *lua.LState) int {
	in := L.ToString(1)
	L.Push(lua.LString(porterstemmer.StemString(in)))
	return 1
}

// copy-pasted from BlobStash
func ltokenize(L *lua.LState) int {
	in := L.ToString(1)
	out, err := tokenize([]byte(in))
	if err != nil {
		panic(err)
	}
	L.Push(luautil.InterfaceToLValue(L, out))
	return 1
}

// copy-pasted from BlobStash
func tokenize(data []byte) (map[string]interface{}, error) {
	out := map[string]interface{}{}
	segmenter := segment.NewWordSegmenter(bytes.NewReader(data))
	for segmenter.Segment() {
		if segmenter.Type() == segment.Letter {
			out[porterstemmer.StemString(segmenter.Text())] = true
		}
	}
	if err := segmenter.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

type docMatch struct {
	doc   map[string]interface{}
	match bool
}

func TestBlobSearchPreQuery(t *testing.T) {
	L := lua.NewState()
	defer L.Close()

	L.SetGlobal("debug", lua.LTrue)
	L.SetGlobal("porterstemmer", L.NewFunction(ltokenize))
	L.SetGlobal("porterstemmer_stem", L.NewFunction(stem))

	prepQuery := func(qs string) lua.LValue {
		L.SetGlobal("query", luautil.InterfaceToLValue(L, map[string]interface{}{
			"qs": qs,
		}))
		if err := L.DoFile("prequery.lua"); err != nil {
			panic(err)
		}
		ret := L.Get(-1)
		// t.Logf("%v", luautil.TableToMap(ret.(*lua.LTable)))
		return ret
	}
	for _, tdata := range []struct {
		qs       string
		expected []map[string]interface{}
	}{
		{
			"ok",
			[]map[string]interface{}{
				map[string]interface{}{"value": "ok", "kind": "text_stems", "prefix": ""},
			},
		},
		{
			"lol ok",
			[]map[string]interface{}{
				map[string]interface{}{"value": "lol", "kind": "text_stems", "prefix": ""},
				map[string]interface{}{"value": "ok", "kind": "text_stems", "prefix": ""},
			},
		},
		{
			"+lol ok",
			[]map[string]interface{}{
				map[string]interface{}{"value": "lol", "kind": "text_stems", "prefix": "+"},
				map[string]interface{}{"value": "ok", "kind": "text_stems", "prefix": ""},
			},
		},
		{
			"+lol -ok",
			[]map[string]interface{}{
				map[string]interface{}{"value": "lol", "kind": "text_stems", "prefix": "+"},
				map[string]interface{}{"value": "ok", "kind": "text_stems", "prefix": "-"},
			},
		},
		{
			"\"lol\" nope",
			[]map[string]interface{}{
				map[string]interface{}{"value": "lol", "kind": "text_match", "prefix": ""},
				map[string]interface{}{"value": "nope", "kind": "text_stems", "prefix": ""},
			},
		},
		{
			"\"lol\" +ok \"yes\" -no tag:boys +tag:work boys",
			[]map[string]interface{}{
				map[string]interface{}{"value": "lol", "kind": "text_match", "prefix": ""},
				map[string]interface{}{"value": "ok", "kind": "text_stems", "prefix": "+"},
				map[string]interface{}{"value": "yes", "kind": "text_match", "prefix": ""},
				map[string]interface{}{"value": "no", "kind": "text_stems", "prefix": "-"},
				map[string]interface{}{"value": "boys", "kind": "tag", "tag": "tag", "prefix": ""},
				map[string]interface{}{"value": "work", "kind": "tag", "tag": "tag", "prefix": "+"},
				map[string]interface{}{"value": "boi", "kind": "text_stems", "prefix": ""},
			},
		},
	} {
		out := prepQuery(tdata.qs)
		m := luautil.TableToMap(out.(*lua.LTable))
		terms := []map[string]interface{}{}
		for _, term := range m["terms"].([]interface{}) {
			terms = append(terms, term.(map[string]interface{}))
		}
		if !reflect.DeepEqual(terms, tdata.expected) {
			t.Errorf("failed to split \"%s\", got %+v, expected %+v", tdata.qs, terms, tdata.expected)
		}
	}
}

func TestBlobSearch(t *testing.T) {
	L := lua.NewState()
	defer L.Close()

	L.SetGlobal("debug", lua.LTrue)
	L.SetGlobal("porterstemmer", L.NewFunction(ltokenize))
	L.SetGlobal("porterstemmer_stem", L.NewFunction(stem))

	prepQuery := func(qs string) lua.LValue {
		L.SetGlobal("query", luautil.InterfaceToLValue(L, map[string]interface{}{
			"qs": qs,
		}))
		if err := L.DoFile("prequery.lua"); err != nil {
			panic(err)
		}
		ret := L.Get(-1)
		t.Logf("%v", luautil.TableToMap(ret.(*lua.LTable)))
		return ret
	}

	matchDoc := func(q lua.LValue, doc map[string]interface{}) bool {
		L.SetGlobal("query", q)
		L.SetGlobal("doc", luautil.InterfaceToLValue(L, doc))
		if err := L.DoFile("match.lua"); err != nil {
			panic(err)
		}
		if L.Get(-1) == lua.LTrue {
			return true
		}
		return false
	}

	for _, tdata := range []struct {
		qs   string
		docs []docMatch
	}{
		{"ok", []docMatch{
			{map[string]interface{}{"content": "ok"}, true},
			{map[string]interface{}{"content": "lol", "title": "Ok it works"}, true},
			{map[string]interface{}{"content": "lol"}, false},
		}},
		{"penny", []docMatch{
			{map[string]interface{}{"content": "my two pennies"}, true},
			{map[string]interface{}{"content": "lol"}, false},
		}},
		{"lol ok", []docMatch{
			{map[string]interface{}{"content": "ok"}, true},
			{map[string]interface{}{"content": "lol"}, true},
			{map[string]interface{}{"title": "lol"}, true},
			{map[string]interface{}{"content": "lol", "title": "Ok it works"}, true},
		}},
		{"ok -lol", []docMatch{
			{map[string]interface{}{"content": "ok lol"}, false},
			{map[string]interface{}{"content": "lol ok"}, false},
			{map[string]interface{}{"content": "lol", "title": "Ok it works"}, false},
			{map[string]interface{}{"content": "ok"}, true},
		}},
		{"ok +lol", []docMatch{
			{map[string]interface{}{"content": "ok"}, false},
			{map[string]interface{}{"content": "lol"}, false},
			{map[string]interface{}{"content": "lol", "title": "Ok it works"}, true},
		}},
		{"+lol ok tag:work", []docMatch{
			{map[string]interface{}{"content": "lol"}, false},
			{map[string]interface{}{"content": "ok"}, false},
			{map[string]interface{}{"content": "lol", "title": "Ok it works"}, true},
		}},
		{"tag:work", []docMatch{
			{map[string]interface{}{"content": "lol", "tags": []interface{}{"work", "lol"}}, true},
			{map[string]interface{}{"content": "lol", "tags": []interface{}{"perso"}}, false},
		}},
	} {
		q := prepQuery(tdata.qs)
		for _, dmatch := range tdata.docs {
			match := matchDoc(q, dmatch.doc)
			t.Logf("query=\"%s\" doc=%+v, expected=%v, got=%v\n", tdata.qs, dmatch.doc, dmatch.match, match)
			if match != dmatch.match {
				t.Errorf("doc %+v test failed for query \"%s\", got %v, expected %v", dmatch.doc, tdata.qs, match, dmatch.match)
			}
		}
	}
}
