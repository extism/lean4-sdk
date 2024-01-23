import Lean.Data.Json
import Lean.Data.Json.Basic
import Lean.Data.Json.Parser
import Lean.Data.Json.Printer

import Extism.Manifest

class Extism.PluginInput (a: Type) where
  toPluginInput: a -> ByteArray

class Extism.ToBytes (a: Type) where
  toBytes: a -> ByteArray

instance : Extism.ToBytes ByteArray where
  toBytes (x: ByteArray) := x

instance : Extism.ToBytes String where
  toBytes := String.toUTF8

instance [Lean.ToJson a] : Extism.ToBytes a where
  toBytes x := (Lean.Json.compress (Lean.ToJson.toJson x)).toUTF8

class Extism.FromBytes (a: Type) where
  fromBytes?: ByteArray -> Except String a

instance : Extism.FromBytes ByteArray where
  fromBytes? (x: ByteArray) := Except.ok x

instance : Extism.FromBytes String where
  fromBytes? x := Except.ok (String.fromUTF8Unchecked x)

instance [Lean.FromJson a] : Extism.FromBytes a where
  fromBytes? x := do
    let j := <- Lean.Json.parse (String.fromUTF8Unchecked x)
    Lean.FromJson.fromJson? j

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
