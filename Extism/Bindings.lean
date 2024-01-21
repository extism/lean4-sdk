@[extern "l_extism_version"]
opaque version : IO String

@[extern "l_extism_initialize"] opaque extismInit : IO Unit

builtin_initialize extismInit

opaque PluginPointed : NonemptyType
def PluginRef : Type := PluginPointed.type
instance : Nonempty PluginRef := PluginPointed.property

opaque FunctionPointed : NonemptyType
def Function : Type := FunctionPointed.type
instance : Nonempty Function := FunctionPointed.property

@[extern "l_extism_plugin_new"]
opaque newPluginRef : ByteArray -> Bool -> IO PluginRef

def newPluginFromFile (path : System.FilePath) (wasi : Bool) : IO PluginRef := do
  let data := <- IO.FS.readBinFile path
  newPluginRef data wasi

