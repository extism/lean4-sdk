# Extism Lean 4 Host SDK

This repo contains the [Lean 4](https://github.com/leanprover/lean4) package for integrating with [Extism](https://github.com/extism/extism)

## Building

The Extism shared object is required for these bindings to work, see our [https://extism.org/docs/install/](installation instructions).

From the root of the repository run:

```sh
lake build
```

To run the tests:

```sh
lake exe test
```

## Getting started

Add the following to your `lakefile.lean`:

```
require extism from git "https://github.com/extism/lean4-sdk" @ "main"
```

### Loading a Plug-in


The primary concept in Extism is the [plug-in](https://extism.org/docs/concepts/plug-in). A plug-in is a code module stored in a `.wasm` file.

Plug-in code can come from a file on disk, object storage or any number of places. Since you may not have one handy, let's load a demo plug-in from the web. Let's
start by creating a main function that loads a plug-in:

```
import Extism

def main : IO Unit := do
  let url := "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm"
  let m := Manifest.new #[Wasm.url url]
  let plugin := <- Plugin.new m #[] True
```

### Calling A Plug-in's Exports

This plug-in was written in Rust and it does one thing, it counts vowels in a string. It exposes one "export" function: `count_vowels`. We can call exports using `Plugin::call`.
Let's add code to call `count_vowels` to our main func:

```
import Extism

def main : IO Unit := do
  let url := "https://github.com/extism/plugins/releases/latest/download/count_vowels.wasm"
  let m := Manifest.new #[Wasm.url url]
  let plugin := <- Plugin.new m #[] True
  let res: String := <- Plugin.call plugin "count_vowels" "Hello, world!"
  IO.println s!"{res}"
  // => {"count":3,"total":3,"vowels":"aeiouAEIOU"}
```

