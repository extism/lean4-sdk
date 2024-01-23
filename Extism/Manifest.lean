import Lean.Data.RBMap
import Lean.Data.Json.Basic
import Lean.Data.Json.FromToJson
import Lean.Data.Json.Printer
import Lean.Data.Json.Parser

private def Pair := String × Lean.Json

structure Extism.WasmFile where
  path: System.FilePath
  name: Option String
  hash: Option String
deriving Lean.FromJson, Lean.ToJson, Inhabited, Repr


private def addIfSome [Lean.ToJson a] (obj: List Pair) (k: String): Option a -> List Pair
  | Option.none => obj
  | Option.some x => (k, Lean.ToJson.toJson x) :: obj


instance : Lean.ToJson Extism.WasmFile where
  toJson x :=
    let m := [
      ("path", Lean.ToJson.toJson x.path)
    ]
    let m := addIfSome m "name" x.name
    let m := addIfSome m "hash" x.hash
    Lean.Json.mkObj m

structure Extism.Memory where
  maxPages: Int
deriving Lean.FromJson, Lean.ToJson, Inhabited, Repr

structure Extism.WasmUrl where
  url: String
  headers: Option (List (String × String))
  method: Option String
  name: Option String
  hash: Option String
deriving Lean.FromJson, Inhabited, Repr

instance : Lean.ToJson Extism.WasmUrl where
  toJson x :=
    let m := [
      ("url", Lean.ToJson.toJson x.url)
    ]
    let h := match x.headers with
      | Option.some x =>
        List.map (fun (k, v) =>
          (k, Lean.toJson v)) x
        |> Lean.Json.mkObj
        |> Option.some
      | Option.none => Option.none
    let m := addIfSome m "headers" h
    let m := addIfSome m "method" x.method
    let m := addIfSome m "name" x.name
    let m := addIfSome m "hash" x.hash
    Lean.Json.mkObj m

inductive Extism.Wasm where
  | wasmFile: Extism.WasmFile -> Extism.Wasm
  | wasmUrl: Extism.WasmUrl -> Extism.Wasm
deriving Inhabited, Repr

instance : Lean.FromJson Extism.Wasm where
   fromJson? := fun j =>
    match Lean.FromJson.fromJson? j with
    | Except.ok (x : Extism.WasmFile) => Except.ok (Extism.Wasm.wasmFile x)
    | Except.error _ => do
      let x := <- Lean.FromJson.fromJson? j
      return (Extism.Wasm.wasmUrl x)

instance : Lean.ToJson Extism.Wasm where
  toJson := fun
    | Extism.Wasm.wasmFile f => Lean.ToJson.toJson f
    | Extism.Wasm.wasmUrl u => Lean.ToJson.toJson u

def Extism.Wasm.file (path: System.FilePath) : Wasm :=
  Extism.Wasm.wasmFile (WasmFile.mk path none none)

def Extism.Wasm.url (url: String) : Wasm :=
  Extism.Wasm.wasmUrl (WasmUrl.mk url none none none none)

structure Extism.Manifest: Type where
  wasm: Array Wasm
  allowedHosts: Option (List String)
  allowedPaths: Option (List (String × String))
  memory: Option Memory
  config: Option (List (String × String))
  timeoutMs: Option Int
deriving Lean.FromJson, Inhabited, Repr

instance : Lean.ToJson Extism.Manifest where
  toJson x :=
    let m := [
      ("wasm", Lean.ToJson.toJson x.wasm)
    ]
    let config := match x.config with
      | Option.some x =>
        List.map (fun (k, v) =>
          (k, Lean.toJson v)) x
        |> Lean.Json.mkObj
        |> Option.some
      | Option.none => Option.none
    let paths := match x.allowedPaths with
      | Option.some x =>
        List.map (fun (k, v) =>
          (k, Lean.toJson v)) x
        |> Lean.Json.mkObj
        |> Option.some
      | Option.none => Option.none
    let m := addIfSome m "memory" x.memory
    let m := addIfSome m "allowed_hosts" x.allowedHosts
    let m := addIfSome m "allowed_paths" paths
    let m := addIfSome m "config" config
    let m := addIfSome m "timeout_ms" x.timeoutMs
    Lean.Json.mkObj m


def Extism.Manifest.new (wasm: Array Extism.Wasm) : Extism.Manifest :=
  Extism.Manifest.mk wasm none none none none none

def Extism.Manifest.withMemoryMax (max: Int) (m: Extism.Manifest) : Extism.Manifest :=
  {m with memory := some (Extism.Memory.mk max)}

def Extism.Manifest.withConfig (k: String) (v: String) (m: Extism.Manifest) :=
  let c := match m.config with
    | Option.none => []
    | Option.some x => x
  {m with config := (k, v) :: c}

def Extism.Manifest.withTimeout (ms: Int) (m: Extism.Manifest) :=
  {m with timeoutMs := Option.some ms}

def Extism.Manifest.allowPath (k: String) (v: String) (m: Extism.Manifest) :=
  let c := match m.allowedPaths with
    | Option.none => []
    | Option.some x => x
  {m with allowedPaths := (k, v) :: c}

def Extism.Manifest.allowHost (k: String) (m: Extism.Manifest) :=
  let c := match m.allowedHosts with
    | Option.none => []
    | Option.some x => x
  {m with allowedHosts := k :: c}

def Extism.Manifest.json (m: Extism.Manifest) : String :=
  let x := Lean.ToJson.toJson m
  Lean.Json.pretty x

def Extism.Manifest.parseJson (s: String) : Except String Extism.Manifest := do
  let x := <- Lean.Json.parse s
  Lean.FromJson.fromJson? x
