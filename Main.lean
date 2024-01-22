import Extism

def helloWorld (curr: Current) : IO Unit := do
  let a := <- Current.getParamI64 curr 0
  let _ := <- Current.setResultI64 curr 0 a
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"

def main : IO Unit := do
  let m := Manifest.new #[Wasm.file "code-functions.wasm"]
  let s := m.json
  IO.println s!"{s}"
  let f := <- Function.new "hello_world" #[ValType.i64] #[ValType.i64] helloWorld
  let plugin := <- Plugin.new m #[f] True
  let input := String.toUTF8 "this is a test"
  let res := <- String.fromUTF8Unchecked <$> plugin.call "count_vowels" input
  IO.println s!"{res}"
