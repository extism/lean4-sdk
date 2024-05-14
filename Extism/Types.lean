import Lean.Data.Json
import Lean.Data.Json.Basic
import Lean.Data.Json.Parser
import Lean.Data.Json.Printer

import Extism.Manifest

/-- `PluginInput` is implemented by types that can be accepted as the wasm input to
    `Plugin.new` --/
class Extism.PluginInput (a: Type) where
  toPluginInput: a -> ByteArray

/-- `ToBytes` is used to convert input data into bytes -/
class Extism.ToBytes (a: Type) where
  toBytes: a -> ByteArray

/-- `FromBytes` is used to convert from bytes to output data -/
class Extism.FromBytes (a: Type) where
  fromBytes?: ByteArray -> Except String a

instance : Extism.ToBytes ByteArray where
  toBytes (x: ByteArray) := x

instance : Extism.ToBytes String where
  toBytes := String.toUTF8


structure Json (a: Type) where
  val: a

instance [Lean.ToJson a] : Extism.ToBytes (Json a) where
  toBytes x := (Lean.Json.compress (Lean.ToJson.toJson x.val)).toUTF8

instance : Extism.FromBytes ByteArray where
  fromBytes? (x: ByteArray) := Except.ok x

instance : Extism.FromBytes String where
  fromBytes? x := match String.fromUTF8? x with
    | some x => Except.ok x
    | none => Except.error "Invalid UTF8 string"

instance [Lean.FromJson a] : Extism.FromBytes (Json a) where
  fromBytes? x := do
    let j <- Lean.Json.parse (String.fromUTF8! x )
    let j <- Lean.FromJson.fromJson? j
    Except.ok (Json.mk j)

instance : Extism.FromBytes UInt64 where
  fromBytes? x :=
    if x.size == 8 then
      Except.ok (ByteArray.toUInt64LE! x)
    else
      Except.error "Invalid input for UInt64"

instance : Extism.PluginInput ByteArray where
  toPluginInput x := x

instance : Extism.PluginInput String where
  toPluginInput := String.toUTF8

instance : Extism.PluginInput Extism.Manifest where
  toPluginInput x := Extism.Manifest.json x |> String.toUTF8
