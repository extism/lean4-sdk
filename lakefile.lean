import Lake

open Lake DSL

unsafe def extismIncludePathImpl (_: Unit) :=
  match unsafeBaseIO (IO.getEnv "EXTISM_INCLUDE_PATH") with
  | .none => "/usr/local/include"
  | .some x => x

unsafe def extismLibPathImpl (_: Unit) :=
  match unsafeBaseIO (IO.getEnv "EXTISM_LIB_PATH") with
  | .none => "/usr/local/lib"
  | .some x => x

@[implemented_by extismIncludePathImpl]
opaque extismIncludePath: Unit -> String
@[implemented_by extismLibPathImpl]
opaque extismLibPath: Unit -> String

package extism {
  -- precompileModules := true
  moreLinkArgs := #["-L" ++ extismLibPath (), "-lextism"]
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
  let weakArgs := #["-I", (← getLeanIncludeDir).toString, "-I", extismIncludePath ()]
  buildO "bindings.c" oFile srcJob weakArgs #["-fPIC", "--std=c11"] "cc" getLeanTrace

extern_lib libleanextism pkg := do
  let name := nameToStaticLib "leanextism"
  let ffiO ← fetch <| pkg.target ``bindings.o
  buildStaticLib (pkg.nativeLibDir / name) #[ffiO]

meta if get_config? env = some "dev" then -- dev is so not everyone has to build it
require «doc-gen4» from git "https://github.com/leanprover/doc-gen4" @ "main"
