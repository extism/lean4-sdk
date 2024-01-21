import Extism

def main : IO Unit := do
  let plugin := <- Plugin.fromFile "code.wasm" True
  let res := <- plugin.call "count_vowels" ByteArray.empty
  IO.println s!"Testing {res}"
  let v := <- version
  IO.println s!"Hello, {v}!"

  -- let a := IO.
  -- let plugin := new_plugin 
