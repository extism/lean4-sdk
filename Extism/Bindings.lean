import Lean.Data.Json
import Lean.Data.Json.Basic
import Lean.Data.Json.Parser
import Lean.Data.Json.Printer

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

@[extern "l_extism_current_set_result_i64"]
opaque Current.setResultI64 : @& Current -> @& Int64 -> @& Int64 -> IO Unit

@[extern "l_extism_current_get_param_i64"]
opaque Current.getParamI64 : @& Current -> @& Int64 -> IO Int64

@[extern "l_extism_current_set_result_i32"]
opaque Current.setResultI32 : @& Current -> @& Int64 -> @& Int32 -> IO Unit

@[extern "l_extism_current_get_param_i32"]
opaque Current.getParamI32 : @& Current -> @& Int64 -> IO Int32

@[extern "l_extism_current_set_result_f64"]
opaque Current.setResultF64 : @& Current -> @& Int64 -> @& Float -> IO Unit

@[extern "l_extism_current_get_param_f64"]
opaque Current.getParamF64 : @& Current -> @& Int64 -> IO Float

@[extern "l_extism_current_set_result_f32"]
opaque Current.setResultF32 : @& Current -> @& Int64 -> @& Float -> IO Unit

@[extern "l_extism_current_get_param_f32"]
opaque Current.getParamF32 : @& Current -> @& Int64 -> IO Float

@[extern "l_extism_plugin_new"]
private opaque newPluginRef : @& ByteArray -> @& Array Function -> Bool -> IO PluginRef

@[extern "l_extism_plugin_call"]
private opaque pluginRefCall : @& PluginRef -> @& String -> @& ByteArray -> IO ByteArray

@[extern "l_extism_function_new"]
private opaque functionNew :
  @& String -> @& String -> @& Array UInt8 -> @& Array UInt8 -> (Current -> IO Unit) -> IO Function

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

private def newPluginFromFile
  (path : System.FilePath)
  (functions: Array Function)
  (wasi : Bool) : IO PluginRef
:= do
  let data := <- IO.FS.readBinFile path
  newPluginRef data functions wasi

class PluginInput (a: Type) where
  toPluginInput: a -> ByteArray

class ToBytes (a: Type) where
  toBytes: a -> ByteArray

instance : ToBytes ByteArray where
  toBytes (x: ByteArray) := x

instance : ToBytes String where
  toBytes := String.toUTF8

instance [Lean.ToJson a] : ToBytes a where
  toBytes x := (Lean.Json.compress (Lean.ToJson.toJson x)).toUTF8

class FromBytes (a: Type) where
  fromBytes?: ByteArray -> Except String a

instance : FromBytes ByteArray where
  fromBytes? (x: ByteArray) := Except.ok x

instance : FromBytes String where
  fromBytes? x := Except.ok (String.fromUTF8Unchecked x)

instance [Lean.FromJson a] : FromBytes a where
  fromBytes? x := do
    let j := <- Lean.Json.parse (String.fromUTF8Unchecked x)
    Lean.FromJson.fromJson? j

instance : PluginInput ByteArray where
  toPluginInput x := x

instance : PluginInput String where
  toPluginInput := String.toUTF8

def Function.newInNamespace
  (ns : String)
  (name: String)
  (params: Array ValType)
  (results: Array ValType)
  (f: Current -> IO Unit) : IO Function
:=
  let params := Array.map ValType.toInt params
  let results := Array.map ValType.toInt results
  functionNew ns name params results f

def Function.new
  (name: String)
  (params: Array ValType)
  (results: Array ValType)
  (f: Current -> IO Unit) : IO Function
:=
  Function.newInNamespace "extism:host/user" name params results f

structure Plugin where
  inner: PluginRef
  functions: Array Function

def Plugin.new [PluginInput a]
  (data: a)
  (functions: Array Function)
  (wasi : Bool) : IO Plugin
:= do
  let input := PluginInput.toPluginInput data
  let x := <- newPluginRef input functions wasi
  return (Plugin.mk x #[])

def Plugin.fromFile
  (path: System.FilePath)
  (functions: Array Function)
  (wasi : Bool) : IO Plugin
:= do
  let x := <- newPluginFromFile path functions wasi
  return (Plugin.mk x #[])

def Plugin.call [ToBytes a] [FromBytes b]
  (plugin: Plugin)
  (funcName: String)
  (data: a) : IO b
:= do
  let data := ToBytes.toBytes data
  let res := <- pluginRefCall plugin.inner funcName data
  IO.ofExcept (FromBytes.fromBytes? res)

def Plugin.pipe [ToBytes a] [FromBytes b]
  (plugin: Plugin)
  (names: List String)
  (data: a) : IO b
:= do
  let data := ToBytes.toBytes data
  let res := <- List.foldlM (fun acc x =>
    Plugin.call plugin x acc) data names
  FromBytes.fromBytes? res
  |> IO.ofExcept


