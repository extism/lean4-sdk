import Lean.Data.Json.Basic
import Lean.Data.Json.FromToJson
import Lean.Data.Json.Printer
import Lean.Data.Json.Parser

private def Pair := String × Lean.Json

/-- Wasm file -/
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

/-- Wasm URL -/
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

/-- Wasm type -/
inductive Extism.Wasm where
  | wasmFile: Extism.WasmFile -> Extism.Wasm
  | wasmUrl: Extism.WasmUrl -> Extism.Wasm
deriving Inhabited, Repr

instance : Lean.FromJson Extism.Wasm where
   fromJson? := fun j =>
    match Lean.FromJson.fromJson? j with
    | Except.ok (x : Extism.WasmFile) => Except.ok (Extism.Wasm.wasmFile x)
    | Except.error _ => do
      let x <- Lean.FromJson.fromJson? j
      return (Extism.Wasm.wasmUrl x)

instance : Lean.ToJson Extism.Wasm where
  toJson := fun
    | Extism.Wasm.wasmFile f => Lean.ToJson.toJson f
    | Extism.Wasm.wasmUrl u => Lean.ToJson.toJson u

/-- Create a new `Wasm` from a path on disk -/
def Extism.Wasm.file (path: System.FilePath) : Wasm :=
  Extism.Wasm.wasmFile (WasmFile.mk path none none)

/-- Create a new `Wasm` from a URL -/
def Extism.Wasm.url (url: String) : Wasm :=
  Extism.Wasm.wasmUrl (WasmUrl.mk url none none none none)

/-- Memory limits -/
structure Extism.Memory where
  maxPages: Option Int
  maxHttpResponseBytes: Option Int
  maxVarBytes: Option Int
deriving Lean.FromJson, Lean.ToJson, Inhabited, Repr

/-- Extism Manifest, used to link and configure plugins -/
structure Extism.Manifest: Type where
  wasm: Array Wasm
  allowedHosts: Option (List String)
  allowedPaths: Option (List (System.FilePath × System.FilePath))
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
          (k.toString, Lean.toJson v)) x
        |> Lean.Json.mkObj
        |> Option.some
      | Option.none => Option.none
    let m := addIfSome m "memory" x.memory
    let m := addIfSome m "allowed_hosts" x.allowedHosts
    let m := addIfSome m "allowed_paths" paths
    let m := addIfSome m "config" config
    let m := addIfSome m "timeout_ms" x.timeoutMs
    Lean.Json.mkObj m


/-- Create a new Manifest from an array of `Wasm` -/
def Extism.Manifest.new (wasm: Array Extism.Wasm) : Extism.Manifest :=
  Extism.Manifest.mk wasm none none none none none

/-- Set memory max pages -/
def Extism.Manifest.withMaxPages (max: Int) (m: Extism.Manifest) : Extism.Manifest :=
  match m.memory with
  | Option.none =>
    {m with memory := some (Extism.Memory.mk (some max) none none)}
  | Option.some x =>
    {m with memory := some ({x with maxPages := max})}


/-- Set memory max HTTP response size in bytes -/
def Extism.Manifest.withMaxHttpResponseBytes (max: Int) (m: Extism.Manifest) : Extism.Manifest :=
  match m.memory with
  | Option.none =>
    {m with memory := some (Extism.Memory.mk none (some max) none)}
  | Option.some x =>
    {m with memory := some ({x with maxHttpResponseBytes := max})}


/-- Set the maxiumum size of the Extism var store in bytes -/
def Extism.Manifest.withMaxVarBytes (max: Int) (m: Extism.Manifest) : Extism.Manifest :=
  match m.memory with
  | Option.none =>
    {m with memory := some (Extism.Memory.mk none none (some max))}
  | Option.some x =>
    {m with memory := some ({x with maxVarBytes := max})}

/-- Set configuration key -/
def Extism.Manifest.withConfig (k: String) (v: String) (m: Extism.Manifest) :=
  let c := match m.config with
    | Option.none => []
    | Option.some x => x
  {m with config := (k, v) :: c}

/-- Set timeout in milliseconds -/
def Extism.Manifest.withTimeout (ms: Int) (m: Extism.Manifest) :=
  {m with timeoutMs := Option.some ms}

/-- Allow access to a path on disk -/
def Extism.Manifest.allowPath (k: System.FilePath) (v: Option System.FilePath) (m: Extism.Manifest) :=
  let c := match m.allowedPaths with
    | Option.none => []
    | Option.some x => x
  let v := match v with
    | Option.none => k
    | Option.some v => v
  {m with allowedPaths := (k, v) :: c}

/-- Allow host -/
def Extism.Manifest.allowHost (k: String) (m: Extism.Manifest) :=
  let c := match m.allowedHosts with
    | Option.none => []
    | Option.some x => x
  {m with allowedHosts := k :: c}

/-- Convenience function to convert an `Extism.Manifest` to a JSON string -/
def Extism.Manifest.json (m: Extism.Manifest) : String :=
  let x := Lean.ToJson.toJson m
  Lean.Json.pretty x

/-- Convenience function to parse an `Extism.Manifest` from a string -/
def Extism.Manifest.parseJson (s: String) : Except String Extism.Manifest := do
  let x <- Lean.Json.parse s
  Lean.FromJson.fromJson? x
