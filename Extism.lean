-- This module serves as the root of the `Extism` library.
-- Import modules here that should be built as part of the library.
import Extism.Bindings
import Extism.Manifest

instance : PluginInput Manifest where
  toPluginInput x := Manifest.json x |> String.toUTF8

