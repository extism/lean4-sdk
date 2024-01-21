@[extern "l_extism_version"]
opaque version : IO String

@[extern "l_extism_initialize"] opaque extismInit : IO Unit
builtin_initialize extismInit

private opaque PluginPointed : NonemptyType
private def PluginRef : Type := PluginPointed.type
instance : Nonempty PluginRef := PluginPointed.property

private opaque FunctionPointed : NonemptyType
private def Function : Type := FunctionPointed.type
instance : Nonempty Function := FunctionPointed.property

@[extern "l_extism_plugin_new"]
private opaque newPluginRef : ByteArray -> Bool -> IO PluginRef

private def newPluginFromFile (path : System.FilePath) (wasi : Bool) : IO PluginRef := do
  let data := <- IO.FS.readBinFile path
  newPluginRef data wasi

@[extern "l_extism_plugin_call"]
private opaque pluginRefCall : PluginRef -> String -> ByteArray -> IO ByteArray

structure Plugin where
  inner: PluginRef
  functions: Array Function

def Plugin.create (data: ByteArray) (wasi : Bool) : IO Plugin := do
  let x := <- newPluginRef data wasi
  return (Plugin.mk x #[])
  
def Plugin.fromFile (path: System.FilePath) (wasi : Bool) : IO Plugin := do
  let x := <- newPluginFromFile path wasi
  return (Plugin.mk x #[])

def Plugin.call (plugin: Plugin) (funcName: String) (data: ByteArray) : IO ByteArray :=
  pluginRefCall plugin.inner funcName data
  

