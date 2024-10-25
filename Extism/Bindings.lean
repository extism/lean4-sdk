import Lean.Data.Json
import Lean.Data.Json.Basic
import Lean.Data.Json.Parser
import Lean.Data.Json.Printer

import Extism.Types

open Extism

/-- Returns the version of the Extism shared object -/
@[extern "l_extism_version"]
opaque version : IO String

@[extern "l_extism_initialize"] opaque extismInit : IO Unit
builtin_initialize extismInit

private opaque PluginPointed : NonemptyType
private def PluginRef : Type := PluginPointed.type
instance : Nonempty PluginRef := PluginPointed.property

private opaque FunctionPointed : NonemptyType
/-- Host function type -/
def Extism.Function : Type := FunctionPointed.type
instance : Nonempty Extism.Function := FunctionPointed.property

private opaque CurrentPointed : NonemptyType
/-- The current plugin, from within a host function -/
def Extism.Current : Type := CurrentPointed.type
instance : Nonempty Extism.Current := CurrentPointed.property

/-- Get current host context -/
@[extern "l_extism_current_get_host_context"]
opaque Current.getHostContext : @& Extism.Current -> IO a

/-- Set result to i64 from inside a host function -/
@[extern "l_extism_current_set_result_i64"]
opaque Current.setResultI64 : @& Extism.Current -> UInt64 -> UInt64 -> IO Unit

/-- Get i64 param from inside a host function -/
@[extern "l_extism_current_get_param_i64"]
opaque Current.getParamI64 : @& Extism.Current -> UInt64 -> IO UInt64

/-- Set result to i32 from inside a host function -/
@[extern "l_extism_current_set_result_i32"]
opaque Current.setResultI32 : @& Extism.Current -> UInt64 -> UInt32 -> IO Unit

/-- Get i32 param from inside a host function -/
@[extern "l_extism_current_get_param_i32"]
opaque Current.getParamI32 : @& Extism.Current -> UInt64 -> IO UInt32

/-- Set result to f64 from inside a host function -/
@[extern "l_extism_current_set_result_f64"]
opaque Current.setResultF64 : @& Extism.Current -> UInt64 -> Float -> IO Unit

/-- Get f64 param from inside a host function -/
@[extern "l_extism_current_get_param_f64"]
opaque Current.getParamF64 : @& Extism.Current -> UInt64 -> IO Float

/-- Set result to f32 from inside a host function -/
@[extern "l_extism_current_set_result_f32"]
opaque Current.setResultF32 : @& Extism.Current -> UInt64 -> Float -> IO Unit

/-- Get f32 param from inside a host function -/
@[extern "l_extism_current_get_param_f32"]
opaque Current.getParamF32 : @& Extism.Current -> UInt64 -> IO Float

@[extern "l_extism_current_alloc"]
private opaque currentAlloc : @& Extism.Current -> UInt64 -> IO UInt64

@[extern "l_extism_current_length"]
private opaque currentLength : @& Extism.Current -> UInt64 -> IO UInt64

@[extern "l_extism_current_free"]
private opaque currentFree : @& Extism.Current -> UInt64 -> IO Unit

@[extern "l_extism_current_read"]
private opaque currentRead : @& Extism.Current -> UInt64 -> IO ByteArray

@[extern "l_extism_current_write"]
private opaque currentWrite : @& Extism.Current -> UInt64 -> @& ByteArray -> IO Unit

def Current.result [ToBytes a] (current: Extism.Current) (index: USize) (v: a) : IO Unit := do
  let data := ToBytes.toBytes v
  let len := data.size
  let n <- currentAlloc current len.toUInt64
  currentWrite current n data
  Current.setResultI64 current index.toUInt64 n

def Current.param [FromBytes a] (current: Extism.Current) (index: USize) : IO a := do
  let n <- Current.getParamI64 current index.toUInt64
  let res <- currentRead current n
  let bytes := FromBytes.fromBytes? res
  IO.ofExcept bytes
  
@[extern "l_extism_plugin_new"]
private opaque newPluginRef : @& ByteArray -> @& Array Function -> Bool -> IO PluginRef

@[extern "l_extism_plugin_call"]
private opaque pluginRefCall : @& PluginRef -> @& String -> @& ByteArray -> IO ByteArray

@[extern "l_extism_plugin_call_with_host_context"]
private opaque pluginRefCallWithHostContext : @& PluginRef -> @& String -> @& ByteArray -> @& A -> IO ByteArray


@[extern "l_extism_function_new"]
private opaque functionNew :
  @& String -> @& String -> @& Array UInt8 -> @& Array UInt8 -> (Current -> IO Unit) -> IO Function

/-- ValType represents the possible types for host function params/results -/
inductive Extism.ValType where
  | i32
  | i64
  | f32
  | f64
  | funcref
  | externref

private def Extism.ValType.toInt (v: Extism.ValType) : UInt8 :=
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
  let data <- IO.FS.readBinFile path
  newPluginRef data functions wasi


/-- Create a new host function in the specified namespace -/
def Extism.Function.newInNamespace
  (ns : String)
  (name: String)
  (params: Array ValType)
  (results: Array ValType)
  (f: Current -> IO Unit) : IO Function
:=
  let params := Array.map ValType.toInt params
  let results := Array.map ValType.toInt results
  functionNew ns name params results f

/-- Create a new host function in the default namespace -/
def Extism.Function.new
  (name: String)
  (params: Array ValType)
  (results: Array ValType)
  (f: Current -> IO Unit) : IO Function
:=
  Function.newInNamespace "extism:host/user" name params results f

/-- Plugin type -/
structure Extism.Plugin where
  inner: PluginRef
  functions: Array Function

/-- Create a new plugin from a `PluginInput` -/
def Extism.Plugin.new [PluginInput a]
  (data: a)
  (functions: Array Function)
  (wasi : Bool) : IO Extism.Plugin
:= do
  let input := PluginInput.toPluginInput data
  let x <- newPluginRef input functions wasi
  return (Extism.Plugin.mk x #[])

/-- Create a new plugin from a file -/
def Extism.Plugin.fromFile
  (path: System.FilePath)
  (functions: Array Function)
  (wasi : Bool) : IO Extism.Plugin
:= do
  let x <- newPluginFromFile path functions wasi
  return (Extism.Plugin.mk x #[])

/-- Call a plugin function, performing conversion of input and output -/
def Extism.Plugin.call [ToBytes a] [FromBytes b]
  (plugin: Extism.Plugin)
  (funcName: String)
  (data: a) : IO b
:= do
  let data := ToBytes.toBytes data
  let res <- pluginRefCall plugin.inner funcName data
  IO.ofExcept (FromBytes.fromBytes? res)

  
/-- Call a plugin function with host context, performing conversion of input and output -/
def Extism.Plugin.callWithHostContext [ToBytes a] [FromBytes b]
  (plugin: Extism.Plugin)
  (funcName: String)
  (hostContext: c)
  (data: a) : IO b
:= do
  let data := ToBytes.toBytes data
  let res <- pluginRefCallWithHostContext plugin.inner funcName data hostContext
  IO.ofExcept (FromBytes.fromBytes? res)

/-- Call multiple plugins, piping the output from the last into the next -/
def Extism.Plugin.pipe [ToBytes a] [FromBytes b]
  (plugin: Plugin)
  (names: List String)
  (data: a) : IO b
:= do
  let data := ToBytes.toBytes data
  let res <- List.foldlM (fun acc x =>
    Plugin.call plugin x acc) data names
  FromBytes.fromBytes? res
  |> IO.ofExcept


/-- Call multiple plugins, piping the output from the last into the next -/
def Extism.Plugin.pipeWithHostContext [ToBytes a] [FromBytes b]
  (plugin: Plugin)
  (names: List String)
  (hostContext: c)
  (data: a) : IO b
:= do
  let data := ToBytes.toBytes data
  let res <- List.foldlM (fun acc x =>
    Plugin.callWithHostContext plugin x hostContext acc) data names
  FromBytes.fromBytes? res
  |> IO.ofExcept


