import Extism.Bindings

structure Plugin where
  inner: PluginRef
  functions: Array Function


def Plugin.create (data: ByteArray) (wasi : Bool) : IO Plugin := do
  let x := <- newPluginRef data wasi
  return (Plugin.mk x #[])
  
def Plugin.fromFile (path: System.FilePath) (wasi : Bool) : IO Plugin := do
  let x := <- newPluginFromFile path wasi
  return (Plugin.mk x #[])
