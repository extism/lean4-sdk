import Extism

def helloWorld (curr: Current) : IO Unit := do
  let a := <- Current.getParamI64 curr 0
  let _ := <- Current.setResultI64 curr 0 a
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"

def hostFunction: IO Unit := do
  let m := Manifest.new #[Wasm.file "wasm/code-functions.wasm"] |> Manifest.withConfig "vowels" "aeiouyAEIOUY"
  let f := <- Function.new "hello_world" #[ValType.i64] #[ValType.i64] helloWorld
  let plugin := <- Plugin.new m #[f] True
  let input := String.toUTF8 "this is a test"
  let res: String := <- plugin.pipe ["count_vowels", "count_vowels"] input
  IO.println s!"{res}"

def fromUrl : IO Unit := do
  let url := "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm"
  let m := Manifest.new #[Wasm.url url]
  let plugin := <- Plugin.new m #[] True
  let res: String := <- Plugin.call plugin "count_vowels" "Hello, world!"
  IO.println s!"{res}"

def main : IO Unit := do
  fromUrl
  hostFunction
