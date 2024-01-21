#include <extism.h>
#include <lean/lean.h>

lean_obj_res l_extism_version() {
  return lean_io_result_mk_ok(lean_mk_string(extism_version()));
}
