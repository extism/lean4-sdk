import Extism

def helloWorld (curr: Current) : IO Unit := do
  let a := <- Current.getParamI64 curr 0
  Current.setResultI64 curr 0 a
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"

def main : IO Unit := do
  let f := <- Function.new "hello_world" #[ValType.i64] #[ValType.i64] helloWorld
  let plugin := <- Plugin.fromFile "code-functions.wasm" #[f] True
  let res := <- String.fromUTF8Unchecked <$> plugin.call "count_vowels" (ByteArray.mk #[65, 65, 65])
  IO.println s!"Testing {res}"
  let v := <- version
  IO.println s!"Hello, {v}!"

  -- let a := IO.
  -- let plugin := new_plugin 
