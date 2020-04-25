package = "lua-resty-ffi-xxhash"
version = "0.1"
source = {
    url = "git://github.com/yorkane/lua-resty-ffi-xxhash.git"
}
description = {
    summary = "LuaJIT FFI-bindings to xxHash",
    detailed = "lua-resty-xxhash contains a LuaJIT FFI-bindings to xxHash, an Extremely fast non-cryptographic hash algorithm.",
    homepage = "https://github.com/yorkane/lua-resty-ffi-xxhash",
    maintainer = "yorkane <whyork@gmail.com>",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["resty.xxhash"] = "lib/resty/xxhash.lua"
    }
}
