@[extern "l_extism_version"]
opaque version : IO String

@[extern "l_extism_initialize"] opaque extismInit : IO Unit

builtin_initialize extismInit

opaque PluginPointed : NonemptyType
def Plugin : Type := PluginPointed.type
instance : Nonempty Plugin := PluginPointed.property

opaque FunctionPointed : NonemptyType
def Function : Type := FunctionPointed.type
instance : Nonempty Function := FunctionPointed.property


@[extern "l_extism_plugin_new"]
opaque newPlugin : ByteArray -> Bool -> IO Plugin

def newPluginFromFile (path : System.FilePath) (wasi : Bool) : IO Plugin := do
  let data := <- IO.FS.readBinFile path
  newPlugin data wasi
