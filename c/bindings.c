#include <extism.h>
#include <lean/lean.h>
#include <stdio.h>

static lean_external_class *g_plugin_class = NULL;
static lean_external_class *g_function_class = NULL;

// Plugin class

lean_object *plugin_box(ExtismPlugin *o) {
  return lean_alloc_external(g_plugin_class, o);
}

ExtismPlugin *plugin_unbox(lean_object *o) {
  return (ExtismPlugin *)(lean_get_external_data(o));
}

static void plugin_finalizer(void *ptr) { extism_plugin_free(ptr); }

inline static void plugin_foreach(void *mod, b_lean_obj_arg fn) {
  // used for `for in`
}

// Function class

lean_object *function_box(ExtismFunction *o) {
  return lean_alloc_external(g_function_class, o);
}

ExtismFunction *function_unbox(lean_object *o) {
  return (ExtismFunction *)(lean_get_external_data(o));
}

static void function_finalizer(void *ptr) { extism_function_free(ptr); }

inline static void function_foreach(void *mod, b_lean_obj_arg fn) {
  // used for `for in`
}

// Initialize

lean_obj_res l_extism_initialize() {
  g_plugin_class =
      lean_register_external_class(plugin_finalizer, plugin_foreach);
  g_function_class =
      lean_register_external_class(function_finalizer, function_foreach);
  return lean_io_result_mk_ok(lean_box(0));
}

// Bindings

lean_obj_res l_extism_version() {
  return lean_io_result_mk_ok(lean_mk_string(extism_version()));
}

lean_obj_res l_extism_plugin_new(b_lean_obj_arg data, uint8_t wasi) {
  size_t dataLen = lean_sarray_size(data);
  void *dataBytes = lean_sarray_cptr(data);

  char *err = NULL;
  ExtismPlugin *plugin =
      extism_plugin_new(dataBytes, dataLen, NULL, 0, wasi, &err);
  if (plugin == NULL) {
    __auto_type e = lean_mk_io_user_error(lean_mk_string(
        err == NULL ? "Unknown error occured in call to Extism plugin" : err));
    if (err != NULL) {
      extism_plugin_new_error_free(err);
    }
    return e;
  }

  return lean_io_result_mk_ok(plugin_box(plugin));
}
