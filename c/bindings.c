#include <extism.h>
#include <lean/lean.h>
#include <stdio.h>
#include <string.h>

static lean_external_class *g_plugin_class = NULL;
static lean_external_class *g_current_plugin_class = NULL;
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

// CurrentPlugin class

typedef struct {
  ExtismCurrentPlugin *plugin;
  const ExtismVal *params;
  size_t nparams;
  ExtismVal *results;
  size_t nresults;
} Current;

lean_object *current_plugin_box(ExtismCurrentPlugin *plugin,
                                const ExtismVal *params, size_t nparams,
                                ExtismVal *results, size_t nresults) {
  Current *c = malloc(sizeof(Current));
  assert(c);
  c->plugin = plugin;
  c->params = params;
  c->nparams = nparams;
  c->results = results;
  c->nresults = nresults;
  return lean_alloc_external(g_current_plugin_class, c);
}

Current *current_plugin_unbox(lean_object *o) {
  return (Current *)(lean_get_external_data(o));
}

static void current_plugin_finalizer(void *ptr) { free(ptr); }

inline static void current_plugin_foreach(void *mod, b_lean_obj_arg fn) {
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
  g_current_plugin_class = lean_register_external_class(
      current_plugin_finalizer, current_plugin_foreach);
  g_function_class =
      lean_register_external_class(function_finalizer, function_foreach);
  return lean_io_result_mk_ok(lean_box(0));
}

// Bindings

lean_obj_res l_extism_version() {
  return lean_io_result_mk_ok(lean_mk_string(extism_version()));
}

lean_obj_res l_extism_plugin_new(b_lean_obj_arg data, lean_obj_arg functions,
                                 uint8_t wasi) {
  size_t dataLen = lean_sarray_size(data);
  void *dataBytes = lean_sarray_cptr(data);

  size_t nFunctions = lean_array_size(functions);
  const ExtismFunction *functionsPtr[nFunctions];

  for (size_t i = 0; i < nFunctions; i++) {
    functionsPtr[i] = function_unbox(lean_array_uget(functions, i));
  }

  char *err = NULL;
  ExtismPlugin *plugin = extism_plugin_new(dataBytes, dataLen, functionsPtr,
                                           nFunctions, wasi == 1, &err);
  if (plugin == NULL) {
    const char *err_s =
        err == NULL ? "Unknown error occured when creating Extism plugin" : err;
    lean_obj_res e = lean_mk_io_user_error(lean_mk_string(err_s));
    if (err != NULL) {
      extism_plugin_new_error_free(err);
    }
    return lean_io_result_mk_error(e);
  }

  return lean_io_result_mk_ok(plugin_box(plugin));
}

lean_obj_res l_extism_plugin_call(b_lean_obj_arg pluginArg,
                                  b_lean_obj_arg funcName,
                                  b_lean_obj_arg input) {
  ExtismPlugin *plugin = plugin_unbox(pluginArg);
  const char *name = lean_string_cstr(funcName);
  size_t dataLen = lean_sarray_size(input);
  void *dataBytes = lean_sarray_cptr(input);
  int32_t rc = extism_plugin_call(plugin, name, dataBytes, dataLen);
  if (rc != 0) {
    const char *err = extism_plugin_error(plugin);
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(
        err == NULL ? "Unknown error occured in call to Extism plugin" : err)));
  }

  size_t length = extism_plugin_output_length(plugin);
  const uint8_t *output = extism_plugin_output_data(plugin);
  lean_obj_res x = lean_mk_empty_byte_array(lean_box(length));
  void *dest = lean_sarray_cptr(x);
  memcpy(dest, output, length);
  lean_sarray_set_size(x, length);
  return lean_io_result_mk_ok(x);
}

static void generic_function_callback(ExtismCurrentPlugin *plugin,
                                      const ExtismVal *params, uint64_t nparams,
                                      ExtismVal *results, uint64_t nresults,
                                      void *userdata) {
  b_lean_obj_arg f = userdata;
  lean_obj_res p =
      current_plugin_box(plugin, params, nparams, results, nresults);
  lean_inc(p);
  lean_inc(f);
  lean_obj_res r = lean_apply_2(f, p, lean_box(0));
  memcpy(results, current_plugin_unbox(p)->results,
         nresults * sizeof(ExtismVal));
  lean_free_object(p);
  lean_free_object(r);
}

lean_obj_res l_extism_function_new(b_lean_obj_arg funcNamespace,
                                   b_lean_obj_arg funcName,
                                   b_lean_obj_arg params,
                                   b_lean_obj_arg results, lean_obj_arg f) {
  const char *name = lean_string_cstr(funcName);
  const char *ns = lean_string_cstr(funcNamespace);
  size_t paramsLen = lean_array_size(params);
  size_t resultsLen = lean_array_size(results);
  ExtismValType paramVals[paramsLen];
  ExtismValType resultVals[resultsLen];

  for (size_t i = 0; i < paramsLen; i++) {
    paramVals[i] = (uint8_t)lean_unbox(lean_array_uget(params, i));
  }
  for (size_t i = 0; i < resultsLen; i++) {
    resultVals[i] = (uint8_t)lean_unbox(lean_array_uget(results, i));
  }
  ExtismFunction *func =
      extism_function_new(name, paramVals, paramsLen, resultVals, resultsLen,
                          generic_function_callback, f, (void *)lean_dec);
  if (func == NULL) {
    return lean_io_result_mk_error(
        lean_mk_io_user_error(lean_mk_string("Unable to create function")));
  }
  extism_function_set_namespace(func, ns);
  return lean_io_result_mk_ok(function_box(func));
}

lean_obj_res l_extism_current_get_param_i64(b_lean_obj_arg current,
                                            uint64_t i) {
  Current *c = current_plugin_unbox(current);
  assert(extism_current_plugin_memory_length(c->plugin, c->params[i].v.i64));
  return lean_io_result_mk_ok(lean_box_uint64(c->params[i].v.i64));
}

lean_obj_res l_extism_current_set_result_i64(b_lean_obj_arg current, uint64_t i,
                                             uint64_t x) {
  Current *c = current_plugin_unbox(current);
  c->results[i].t = I64;
  c->results[i].v.i64 = x;
  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res l_extism_current_get_param_i32(b_lean_obj_arg current,
                                            uint64_t i) {
  Current *c = current_plugin_unbox(current);
  return lean_io_result_mk_ok(lean_box_uint32(c->params[i].v.i32));
}

lean_obj_res l_extism_current_set_result_i32(b_lean_obj_arg current, uint64_t i,
                                             uint32_t x) {
  Current *c = current_plugin_unbox(current);
  c->results[i].t = I32;
  c->results[i].v.i32 = x;
  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res l_extism_current_get_param_f32(b_lean_obj_arg current,
                                            uint64_t i) {
  Current *c = current_plugin_unbox(current);
  return lean_io_result_mk_ok(lean_box_float(c->params[i].v.f32));
}

lean_obj_res l_extism_current_set_result_f32(b_lean_obj_arg current, uint64_t i,
                                             double x) {
  Current *c = current_plugin_unbox(current);
  c->results[i].t = F32;
  c->results[i].v.f32 = x;
  return lean_io_result_mk_ok(lean_box(0));
}
lean_obj_res l_extism_current_get_param_f64(b_lean_obj_arg current,
                                            uint64_t i) {
  Current *c = current_plugin_unbox(current);
  return lean_io_result_mk_ok(lean_box_float(c->params[i].v.f64));
}

lean_obj_res l_extism_current_set_result_f64(b_lean_obj_arg current, uint64_t i,
                                             double x) {
  Current *c = current_plugin_unbox(current);
  c->results[i].t = F64;
  c->results[i].v.f32 = (float)x;
  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res l_extism_current_alloc(b_lean_obj_arg current, uint64_t n) {
  Current *c = current_plugin_unbox(current);
  ExtismMemoryHandle h = extism_current_plugin_memory_alloc(c->plugin, n);
  return lean_io_result_mk_ok(lean_box_uint64(h));
}

lean_obj_res l_extism_current_free(b_lean_obj_arg current, uint64_t x) {
  Current *c = current_plugin_unbox(current);
  extism_current_plugin_memory_free(c->plugin, x);
  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res l_extism_current_length(b_lean_obj_arg current, uint64_t x) {
  Current *c = current_plugin_unbox(current);
  ExtismSize size = extism_current_plugin_memory_length(c->plugin, x);
  return lean_io_result_mk_ok(lean_box_uint64(size));
}

lean_obj_res l_extism_current_read(b_lean_obj_arg current, uint64_t x) {
  Current *c = current_plugin_unbox(current);
  ExtismSize size = extism_current_plugin_memory_length(c->plugin, x);
  lean_obj_res res = lean_mk_empty_byte_array(lean_box(size));
  void *dest = lean_sarray_cptr(res);
  memcpy(dest, extism_current_plugin_memory(c->plugin) + x, size);
  lean_sarray_set_size(res, size);
  return lean_io_result_mk_ok(res);
}

lean_obj_res l_extism_current_write(b_lean_obj_arg current, uint64_t x,
                                    b_lean_obj_arg bytes) {
  Current *c = current_plugin_unbox(current);
  ExtismSize size = extism_current_plugin_memory_length(c->plugin, x);
  size_t arrSize = lean_sarray_size(bytes);
  void *dest = lean_sarray_cptr(bytes);
  memcpy(extism_current_plugin_memory(c->plugin) + x, dest,
         size > arrSize ? arrSize : size);
  return lean_io_result_mk_ok(lean_box(0));
}
