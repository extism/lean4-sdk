@[extern "l_extism_version"]
opaque version : IO String

structure Plugin where
  ptr: UInt64

@[extern "l_extism_plugin_new"]
opaque new_plugin : IO ByteArray -> Bool -> IO Plugin
