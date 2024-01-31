import Extism

open Extism

def helloWorld (curr: Current) : IO Unit := do
  let s: String <- Current.param curr 0
  IO.println s!"Input: {s}"
  Current.result curr 0 s
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"

def hostFunction: IO Unit := do
  let m := Manifest.new #[Wasm.file "wasm/code-functions.wasm"]
    |> Manifest.withConfig "vowels" "aeiouyAEIOUY"
  let f <- Function.new "hello_world" #[ValType.i64] #[ValType.i64] helloWorld
  let plugin <- Plugin.new m #[f] True
  let res: String <- plugin.pipe ["count_vowels", "count_vowels"] "this is a test"
  IO.println s!"Result: {res}"

def fromUrl : IO Unit := do
  let url := "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm"
  let m := Manifest.new #[Wasm.url url]
  let plugin <- Plugin.new m #[] True
  let res: String <- Plugin.call plugin "count_vowels" "Hello, world!"
  IO.println s!"{res}"

def main : IO Unit := do
  fromUrl
  hostFunction
