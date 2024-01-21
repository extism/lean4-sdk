import Extism

def main : IO Unit := do
  let _plugin := <- newPluginFromFile "code.wasm" True
  let v := <- version
  IO.println s!"Hello, {v}!"

  -- let a := IO.
  -- let plugin := new_plugin 
