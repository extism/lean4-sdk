import Extism

open Extism

def isVowel (c: Char) : Bool :=
  c = 'a' || c = 'A' || c = 'e' || c = 'E' || c = 'i' || c = 'I' || c = 'o' || c = 'O' || c = 'u' || c = 'U'

def countVowels' (s: String) : Int :=
  String.foldl (fun acc x => 
    if isVowel x then acc + 1 else acc) 0 s

--/ Example host function, takes one parameter and returns one result
--/ In this case we are just logging the input and returning it
def helloWorld (curr: Current) : IO Unit := do
  let s: String <- Current.param curr 0
  IO.println s!"Input: {s}"
  Current.result curr 0 s
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"
  IO.println "Hello world!!!"

--/ Example with host functions
def hostFunction: IO Unit := do
  let m := Manifest.new #[Wasm.file "wasm/code-functions.wasm"]
    |> Manifest.withConfig "vowels" "aeiouyAEIOUY"
  let f <- Function.new "hello_world" #[ValType.i64] #[ValType.i64] helloWorld
  let plugin <- Plugin.new m #[f] True
  let res: String <- plugin.pipe ["count_vowels", "count_vowels"] "this is a test"
  IO.println s!"Result: {res}"

--/ Example loading a plugin from a URL
def fromUrl : IO Unit := do
  let url := "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm"
  let m := Manifest.new #[Wasm.url url]
  let plugin <- Plugin.new m #[] True
  let res: String <- Plugin.call plugin "count_vowels" "Hello, world!"
  IO.println s!"{res}"

namespace proc
  --/ Process status type
  structure Status where
    name: String
  deriving Lean.FromJson

  --/ Get name of process using /proc/self/status
  def test : IO Unit := do
    let m := 
      Manifest.new #[Wasm.file "wasm/extproc.wasm"]
      |> Manifest.allowPath "/proc" "/proc"
    let plugin <- Plugin.new m #[] True
    let res: Json Status <- Plugin.call plugin "status" ""
    assert! res.val.name == "test"
    IO.println s!"Name: {res.val.name}"
end proc

structure VowelCount where
  count: Int
deriving Lean.FromJson

def countVowels (s: String) : IO Int := do
  let m := Manifest.new #[Wasm.file "wasm/code.wasm"]
  let plugin <- Plugin.new m #[] True
  let res: Json VowelCount <- plugin.call "count_vowels" s
  return res.val.count

def main : IO Unit := do
  fromUrl
  hostFunction
  proc.test
  let testing <- countVowels "testing"
  assert! testing = countVowels' "testing"
