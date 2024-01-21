import Lake

open Lake DSL

package extism {
  -- precompileModules := true
  moreLinkArgs := #["-lextism"]
}

lean_lib Extism 
  -- add library configuration options here

@[default_target]
lean_exe test {
  root := `Main
}

target bindings.o pkg : FilePath := do
  let oFile := pkg.buildDir / "c" / "bindings.o"
  let srcJob ← inputFile <| pkg.dir / "c" / "bindings.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString, "-I", "/usr/local/include"]
  buildO "bindings.c" oFile srcJob weakArgs #["-fPIC", "--std=c11"] "cc" getLeanTrace

extern_lib libleanextism pkg := do
  let name := nameToStaticLib "leanextism"
  let ffiO ← fetch <| pkg.target ``bindings.o
  buildStaticLib (pkg.nativeLibDir / name) #[ffiO]
