import Lake

open Lake DSL

def extismIncludePath := "/usr/local/include"
def extismLibPath := "/usr/local/lib"

package extism {
  -- precompileModules := true
  moreLinkArgs := #["-L" ++ extismLibPath, "-lextism"]
}

lean_lib Extism 
  -- add library configuration options here

@[default_target]
lean_exe test {
  root := `Test
}

target bindings.o pkg : FilePath := do
  let oFile := pkg.buildDir / "c" / "bindings.o"
  let srcJob ← inputFile <| pkg.dir / "c" / "bindings.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString, "-I", extismIncludePath]
  buildO "bindings.c" oFile srcJob weakArgs #["-fPIC", "--std=c11"] "cc" getLeanTrace

extern_lib libleanextism pkg := do
  let name := nameToStaticLib "leanextism"
  let ffiO ← fetch <| pkg.target ``bindings.o
  buildStaticLib (pkg.nativeLibDir / name) #[ffiO]
