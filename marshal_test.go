package libclash

import (
	"encoding/json"
	"testing"
)

type wire struct {
	Name  string   `json:"name"`
	Items []string `json:"items"`
	N     int      `json:"n"`
}

func TestMarshalJSONMatchesStdlib(t *testing.T) {
	cases := []any{
		&struct{}{},
		&wire{},
		&wire{Name: "a", Items: []string{"x", "y"}, N: 42},
		&wire{Name: "中文 \" \\ \n", Items: []string{""}, N: -1},
		[]int{},
		map[string]int{"a": 1, "b": 2},
	}
	for _, c := range cases {
		want, err := json.Marshal(c)
		if err != nil {
			t.Fatal(err)
		}
		got := marshalJSON(c)
		if got != string(want) {
			t.Fatalf("marshalJSON = %q, stdlib = %q", got, want)
		}
	}
}

// the returned string must stay valid and unchanged after GC pressure
func TestMarshalJSONSurvivesGC(t *testing.T) {
	got := marshalJSON(&wire{Name: "persist", Items: []string{"a", "b", "c"}, N: 7})
	want := `{"name":"persist","items":["a","b","c"],"n":7}`
	for i := 0; i < 200; i++ {
		_ = make([]byte, 128*1024)
	}
	if got != want {
		t.Fatalf("string changed after GC pressure: %q", got)
	}
}

// an unmarshalable type must return "" instead of panicking
func TestMarshalJSONDoesNotPanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("panicked: %v", r)
		}
	}()
	if got := marshalJSON(func() {}); got != "" {
		t.Fatalf("expected empty payload, got %q", got)
	}
}
