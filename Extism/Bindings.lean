@[extern "l_extism_version"]
opaque version : IO String

@[extern "l_extism_initialize"] opaque extismInit : IO Unit
builtin_initialize extismInit

private opaque PluginPointed : NonemptyType
private def PluginRef : Type := PluginPointed.type
instance : Nonempty PluginRef := PluginPointed.property

private opaque FunctionPointed : NonemptyType
def Function : Type := FunctionPointed.type
instance : Nonempty Function := FunctionPointed.property

private opaque CurrentPointed : NonemptyType
def Current : Type := CurrentPointed.type
instance : Nonempty Current := CurrentPointed.property


inductive ValType where
  | i32
  | i64
  | f32
  | f64
  | funcref
  | externref

def ValType.toInt (v: ValType) : UInt8 :=
  match v with
  | i32 => 0
  | i64 => 1
  | f32 => 2
  | f64 => 3
  | funcref => 4
  | externref => 5

@[extern "l_extism_plugin_new"]
private opaque newPluginRef : ByteArray -> Array Function -> Bool -> IO PluginRef

private def newPluginFromFile (path : System.FilePath) (functions: Array Function) (wasi : Bool) : IO PluginRef := do
  let data := <- IO.FS.readBinFile path
  newPluginRef data functions wasi

@[extern "l_extism_plugin_call"]
private opaque pluginRefCall : PluginRef -> String -> ByteArray -> IO ByteArray

@[extern "l_extism_function_new"]
private opaque functionNew : String -> String -> Array UInt8 -> Array UInt8 -> (Current -> IO Unit) -> IO Function

class PluginInput (a: Type) where
  toPluginInput: a -> ByteArray

instance : PluginInput ByteArray where
  toPluginInput x := x

instance : PluginInput String where
  toPluginInput := String.toUTF8

def Function.newInNamespace (ns : String) (name: String) (params: Array ValType) (results: Array ValType) (f: Current -> IO Unit) : IO Function :=
  functionNew ns name (Array.map ValType.toInt params) (Array.map ValType.toInt results) f 

def Function.new (name: String) (params: Array ValType) (results: Array ValType) (f: Current -> IO Unit) : IO Function :=
  Function.newInNamespace "extism:host/user" name params results f
  
structure Plugin where
  inner: PluginRef
  functions: Array Function

def Plugin.new [PluginInput a] (data: a) (functions: Array Function) (wasi : Bool) : IO Plugin := do
  let input := PluginInput.toPluginInput data
  let s := String.fromUTF8Unchecked input
  IO.println s!"Input {s}"
  let x := <- newPluginRef input functions wasi
  return (Plugin.mk x #[])
  
def Plugin.fromFile (path: System.FilePath) (functions: Array Function) (wasi : Bool) : IO Plugin := do
  let x := <- newPluginFromFile path functions wasi
  return (Plugin.mk x #[])

def Plugin.call (plugin: Plugin) (funcName: String) (data: ByteArray) : IO ByteArray :=
  pluginRefCall plugin.inner funcName data

def Plugin.pipe (plugin: Plugin) (names: List String) (data: ByteArray) : IO ByteArray :=
  List.foldlM (fun acc x =>
    Plugin.call plugin x acc) data names
  
@[extern "l_extism_current_set_result_i64"]
private opaque setFunctionResultI64 : Current -> Int64 -> Int64 -> IO Unit

partial def Current.setResultI64 (c: Current) (i: Int64) (x: Int64) : IO Unit :=
  setFunctionResultI64 c i x

@[extern "l_extism_current_get_param_i64"]
private opaque getFunctionParamI64 : Current -> Int64 -> IO Int64

partial def Current.getParamI64 (c: Current) (i: Int64) : IO Int64 :=
  getFunctionParamI64 c i
