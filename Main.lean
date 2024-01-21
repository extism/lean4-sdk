import Extism

def main : IO Unit := do
  let v := <- version
  IO.println s!"Hello, {v}!"
