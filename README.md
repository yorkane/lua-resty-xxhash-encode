# lua-resty-xxhash
openresty lua ffi binding for xxhash and base64 wraps

# Installation

## Source 
```bash
# export INST_LIBDIR=/usr/local/openresty/site/lualib # manual installed location
# export INST_LUADIR=/usr/local/openresty/site/lualib # manual installed location
git clone https://github.com/yorkane/lua-resty-xxhash-encode.git
cd lua-resty-xxhash-encode
make && make install
```

## Luarocks
```
export INST_LIBDIR=/usr/local/lib/lua/5.1
export INST_LUADIR=/usr/local/share/lua/5.1
luarocks install lua-resty-xxhash-encode
```

# Usages:
```lua

local bec = require('resty.xxhashencode')
local b = bec.uint_byte(bec.max_int)
local num = bec.byte_uint(b)
local ulong = bec.xxhash64(teststr)

```