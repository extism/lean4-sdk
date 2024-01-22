import Lean.Data.RBMap
import Lean.Data.Json.Basic
import Lean.Data.Json.FromToJson
import Lean.Data.Json.Printer
import Lean.Data.Json.Parser


structure WasmFile where
  path: System.FilePath
  name: Option String
  hash: Option String
deriving Lean.FromJson, Lean.ToJson, Inhabited, Repr


def addIfSome [Lean.ToJson a] (obj: List (String × Lean.Json))  (k: String): Option a -> List (String × Lean.Json)
  | Option.none => obj
  | Option.some x => (k, Lean.ToJson.toJson x) :: obj


instance : Lean.ToJson WasmFile where
  toJson x := 
    let m := [
      ("path", Lean.ToJson.toJson x.path)
    ]
    let m := addIfSome m "name" x.name
    let m := addIfSome m "hash" x.hash
    Lean.Json.mkObj m

structure Memory where
  maxPages: Int
deriving Lean.FromJson, Lean.ToJson, Inhabited, Repr

structure WasmUrl where
  url: String
  headers: Option (List (String × String))
  method: Option String
  name: Option String
  hash: Option String
deriving Lean.FromJson, Inhabited, Repr

instance : Lean.ToJson WasmUrl where
  toJson x := 
    let m := [
      ("url", Lean.ToJson.toJson x.url)
    ]
    let m := addIfSome m "headers" x.headers 
    let m := addIfSome m "method" x.method
    let m := addIfSome m "name" x.name
    let m := addIfSome m "hash" x.hash
    Lean.Json.mkObj m

inductive Wasm where
  | wasmFile: WasmFile -> Wasm
  | wasmUrl: WasmUrl -> Wasm
deriving Inhabited, Repr

instance : Lean.FromJson Wasm where
   fromJson? := fun j =>
    match Lean.FromJson.fromJson? j with
    | Except.ok (x : WasmFile) => Except.ok (Wasm.wasmFile x)
    | Except.error _ => do
      let x := <- Lean.FromJson.fromJson? j
      return (Wasm.wasmUrl x)

instance : Lean.ToJson Wasm where
  toJson := fun 
    | Wasm.wasmFile f => Lean.ToJson.toJson f
    | Wasm.wasmUrl u => Lean.ToJson.toJson u

def Wasm.file (path: System.FilePath) : Wasm :=
  Wasm.wasmFile (WasmFile.mk path none none)

def Wasm.url (url: String) : Wasm :=
  Wasm.wasmUrl (WasmUrl.mk url none none none none)

structure Manifest: Type where
  wasm: Array Wasm
  allowedHosts: Option (Array String)
  allowedPaths: Option (List (String × String))
  memory: Option Memory
deriving Lean.FromJson, Inhabited, Repr

instance : Lean.ToJson Manifest where
  toJson x := 
    let m := [
      ("wasm", Lean.ToJson.toJson x.wasm)
    ]
    let m := addIfSome m "memory" x.memory
    let m := addIfSome m "allowed_hosts" x.allowedHosts
    let m := addIfSome m "allowed_paths" x.allowedPaths
    Lean.Json.mkObj m


def Manifest.new (wasm: Array Wasm) : Manifest :=
  Manifest.mk wasm none none none

def Manifest.withMemoryMax (m: Manifest) (max: Int) : Manifest :=
  {m with memory := some (Memory.mk max)}

def Manifest.json (m: Manifest) : String :=
  let x := Lean.ToJson.toJson m
  Lean.Json.pretty x

def Manifest.parseJson (s: String) : Except String Manifest := do
  let x := <- Lean.Json.parse s
  Lean.FromJson.fromJson? x
