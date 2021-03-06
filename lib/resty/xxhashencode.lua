local error, concat = error, table.concat
local tostring, tonumber, reverse, floor, byte, sub, char = tostring, tonumber, string.reverse, math.floor, string.byte, string.sub, string.char
local type = type
local ceil = math.ceil
local ffi = require "ffi"
local ffi_string, ffi_new = ffi.string, ffi.new
local bit = require('bit')
local band, bor, bxor, lshift, rshift, rolm, bnot = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol, bit.bnot
local new_tab, insert, mod = table.new, table.insert, math.fmod

local tag = 'xxhash'
local tablepool = require('tablepool')
local array = function(size)
	return tablepool.fetch(tag, size, 0)
end
local release = function(tab, noclear)
	return tablepool.release(tag, tab, noclear)
end

local _M = {
	version = "1.3.4",
	max_int = 4294967295,
	max_int_b64 = 'D_____',
	max_long = 9199999999999999999,
	max_long_b64 = 'HHAs90Gdm---',
	max_int_chars = 'ÿÿÿÿ', -- This value will be overwritten by following code
	max_int_chars_1 = 'sssdsfsfsd'
}

local str_buf_size = 4096
local str_buf
local c_buf_type = ffi.typeof("char[?]")
local c_size_t_list = ffi.typeof("size_t[?]")
local function get_string_buf(size)
	if size > str_buf_size then
		return ffi_new(c_buf_type, size)
	end
	if not str_buf then
		str_buf = ffi_new(c_buf_type, str_buf_size)
	end
	return str_buf
end

local function load_shared_lib(so_name)
	local tried_paths = {}
	local i = 1
	for k, _ in package.cpath:gmatch("[^;]+") do
		local fpath = k:match("(.*/)")
		fpath = fpath .. so_name
		local f = io.open(fpath)
		if f ~= nil then
			io.close(f)
			return ffi.load(fpath)
		end
		tried_paths[i] = fpath
		i = i + 1
	end
	local f = io.open(so_name)
	if f ~= nil then
		io.close(f)
		return ffi.load(so_name)
	end
	tried_paths[#tried_paths + 2] = 'tried above paths but can not load ' .. so_name
	error(concat(tried_paths, '\n'))
end

local encoding = load_shared_lib("librestyxxhashencode.so")

_M.encode = encoding
ffi.cdef([[

size_t modp_b2_encode(char* dest, const char* str, size_t len);
size_t modp_b2_decode(char* dest, const char* str, size_t len);

size_t modp_b16_encode(char* dest, const char* str, size_t len,
    uint32_t out_in_lowercase);
size_t modp_b16_decode(char* dest, const char* src, size_t len);

size_t b32_encode(char* dest, const char* src, size_t len, uint32_t no_padding,
    uint32_t hex);
size_t b32_decode(char* dest, const char* src, size_t len, uint32_t hex);

size_t modp_b85_encode(char* dest, const char* str, size_t len);
size_t modp_b85_decode(char* dest, const char* str, size_t len);


size_t modp_b64w_encode(char* dest, const char* str, size_t len);
size_t modp_b64w_decode(char* dest, const char* src, size_t len);

size_t xxhash128_b64(char *dest_b64, char *dest_byte, const char *str, size_t length, unsigned long long const seed);
size_t xxhash128(const void* data, size_t length, unsigned char *dest, uint64_t seed);


uint64_t parse_num(const char *str);
unsigned int int_base64(char* dest, unsigned int num);
unsigned int base64_int(const char* dest, int num);
size_t long_base64(char* dest, long num);
unsigned long base64_long(const char* dest, int len);
size_t xxhash64_b64(char* dest, const char* str, size_t length, unsigned long long const seed);
size_t xxhash32_b64(char* dest, const char* str, size_t length, unsigned int const seed);
unsigned long djb2_hash(const char* str);
unsigned int xxhash32(const char* str, size_t length,  unsigned int seed);
unsigned long long  xxhash64(const char* str, size_t length, unsigned long long const seed);
uint64_t xxh3(const char *str, size_t length, unsigned long long const seed);
unsigned int get_unsigned_int(const char *buffer, int offset, int length);
unsigned int get_unsigned_int_from(int a, int b, int c, int d);

size_t uint_bytes(char *dest, uint32_t num);
size_t bytes_uint(const char *str, size_t index, int length);
size_t uint64_bytes(char *dest, uint64_t num);
uint64_t bytes_uint64(const char *buffer, size_t offset, int length);
]])

local function check_encode_str(s)
	if type(s) ~= 'string' then
		if not s then
			s = ''
		else
			s = tostring(s)
		end
	end

	return s
end

function _M.parse_num(str)
	return encoding.parse_num(str)
end

local function base64_encoded_length(len, no_padding)
	return no_padding and floor((len * 8 + 5) / 6) or
			floor((len + 2) / 3) * 4
end

function _M.encode_base64url(s)
	if type(s) ~= "string" then
		return nil, "must provide a string"
	end

	local slen = #s
	local dlen = base64_encoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b64w_encode(dst, s, slen)
	return ffi_string(dst, r_dlen)
end

local function check_decode_str(s, level)
	if type(s) ~= 'string' then
		error("string argument only", level + 2)
	end
end

local function base64_decoded_length(len)
	return floor((len + 3) / 4) * 3
end

function _M.decode_base64url(s)
	if type(s) ~= "string" then
		return nil, "must provide a string"
	end

	local slen = #s
	local dlen = base64_decoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b64w_decode(dst, s, slen)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	return ffi_string(dst, r_dlen)
end

local function base32_encoded_length(len)
	return floor((len + 4) / 5) * 8
end

---encode_base32
---@param s string @ byte to encode
---@param no_padding boolean
---@param hex boolean @ with hex-char table or standard-char table
local function encode_base32(s, no_padding, hex)
	s = check_encode_str(s)

	local slen = #s
	local no_padding_int = no_padding and 1 or 0
	local dlen = base32_encoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.b32_encode(dst, s, slen, no_padding_int, hex and 1 or 0)
	return ffi_string(dst, r_dlen)
end

function _M.encode_base32(s, no_padding)
	return encode_base32(s, no_padding, 0)
end

function _M.encode_base32hex(s, no_padding)
	return encode_base32(s, no_padding, 1)
end

local function base32_decoded_length(len)
	return floor(len * 5 / 8)
end

local function decode_base32(s, hex)
	check_decode_str(s, 1)

	local slen = #s
	if slen == 0 then
		return ""
	end

	local dlen = base32_decoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.b32_decode(dst, s, slen, hex)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	return ffi_string(dst, r_dlen)
end

function _M.decode_base32(s)
	return decode_base32(s, 0)
end

function _M.decode_base32hex(s)
	return decode_base32(s, 1)
end

local function base16_encoded_length(len)
	return len * 2
end

function _M.encode_base16(s, out_in_lowercase)
	s = check_encode_str(s)

	local out_in_lowercase_int = out_in_lowercase and 1 or 0
	local slen = #s
	local dlen = base16_encoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b16_encode(dst, s, slen, out_in_lowercase_int)
	return ffi_string(dst, r_dlen)
end

local function base16_decoded_length(len)
	return len / 2
end

function _M.decode_base16(s)
	check_decode_str(s, 1)

	local slen = #s
	if slen == 0 then
		return ""
	end

	local dlen = base16_decoded_length(slen)
	if floor(dlen) ~= dlen then
		return nil, "invalid input"
	end

	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b16_decode(dst, s, slen)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	return ffi_string(dst, r_dlen)
end

local function base2_encoded_length(len)
	return len * 8
end

function _M.encode_base2(s)
	s = check_encode_str(s)

	local slen = #s
	local dlen = base2_encoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b2_encode(dst, s, slen)
	return ffi_string(dst, r_dlen)
end

local function base2_decoded_length(len)
	return len / 8
end

function _M.decode_base2(s)
	check_decode_str(s, 1)

	local slen = #s
	if slen == 0 then
		return ""
	end

	local dlen = base2_decoded_length(slen)
	if floor(dlen) ~= dlen then
		return nil, "invalid input"
	end

	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b2_decode(dst, s, slen)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	return ffi_string(dst, r_dlen)
end

local function base85_encoded_length(len)
	return len / 4 * 5
end

function _M.encode_base85(s)
	s = check_encode_str(s)

	local slen = #s
	if slen == 0 then
		return ""
	end

	local dlen = base85_encoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b85_encode(dst, s, slen)
	return ffi_string(dst, r_dlen)
end

local function base85_decoded_length(len)
	return ceil(len / 5) * 4
end

function _M.decode_base85(s)
	check_decode_str(s, 1)

	local slen = #s
	if slen == 0 then
		return ""
	end

	local dlen = base85_decoded_length(slen)
	local dst = get_string_buf(dlen)
	local r_dlen = encoding.modp_b85_decode(dst, s, slen)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	return ffi_string(dst, r_dlen)
end

---int_base64 this method is much faster than long_base64, max int 2147483647, but you can exceed 1 digit to 21474836479
---@param int number @ max number is 2147483647, which is `B_____`
---@return string @ base64 string
function _M.int_base64(int)
	local dst = get_string_buf(7)
	local r_dlen = encoding.int_base64(dst, int)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	local str
	str = ffi_string(dst, r_dlen)
	return str
end

---base64_int
---@param b64_str string @ max `D_____`
---@return number @ int number max 4294967295
function _M.base64_int(b64_str)
	local ext
	local len = #b64_str -- normal int will not exceed 6 chars
	if len > 6 then
		ext = byte(b64_str, len) - 48 -- convert byte to number
		b64_str = sub(b64_str, 1, len - 2) -- remove last 2 chars
	end
	if ext then
		return (encoding.base64_int(b64_str, len - 1) * 10) + ext
	end
	return encoding.base64_int(b64_str, len - 1)
end

---long_base64
---@param long number @ max number is 2147483647, which is `B_____`
---@return string @ base64 string
function _M.long_base64(long)
	local dst = get_string_buf(7)
	local r_dlen = encoding.long_base64(dst, long)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	return ffi_string(dst, r_dlen)
end

---base64_long
---@param b64_str string
---@return number, number @ lua number, cdata<long>
function _M.base64_long(b64_str)
	local n = encoding.base64_long(b64_str, #b64_str - 1)
	return n
end

-----xxhash64_b64 digest text into hashed base64 text
-----@param str string
-----@param seed number
function _M.xxhash64_b64(str, seed, with_padding)
	if not str then
		return nil, "empty input"
	end
	local dst = get_string_buf(11)
	local r_dlen = encoding.xxhash64_b64(dst, str, #str, seed or 33)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	local res = ffi_string(dst, r_dlen)
	if r_dlen == 11 or not with_padding then
		return res
	end
	local rep = string.rep('=', 11 - r_dlen)
	return rep
	--return reverse(ffi_string(dst, r_dlen))
end

---xxhash32_b64 digest text into hashed base64 text
---@param str string
---@param seed number
---@return string @base64 encoded text
function _M.xxhash32_b64(str, seed)
	local dst = get_string_buf(7)
	local r_dlen = encoding.xxhash32_b64(dst, str, #str, seed or 33)
	if r_dlen == -1 then
		return nil, "invalid input"
	end
	--return reverse(ffi_string(dst, r_dlen))
	return ffi_string(dst, r_dlen)
	--	local int = encoding.xxhash32(str, #str, seed or 33)
	--	local dst = get_string_buf(7)
	--	local r_dlen = encoding.int_base64(dst, int)
	--	return ffi_string(dst, r_dlen)
end

function _M.djb2_hash(str)
	local n = encoding.djb2_hash(str)
	if n then
		return tonumber(n)
	end
end

---xxhash64
---@param str string @base64 string
---@param seed number
---@return number @ULL number, using tonumber if you need string
function _M.xxhash64(str, seed)
	local n = encoding.xxhash64(str, #str, seed or 33)
	return n
end

function _M.xxhash32(str, seed)
	local n = encoding.xxhash32(str, #str, seed or 33)
	return n
end

function _M.xxhash3(str, seed)
	local n = encoding.xxh3(str, #str, seed or 33)
	return n
end

function _M.xxhash128(str, seed)
	local dst = get_string_buf(16)
	local n = encoding.xxhash128(str, #str, dst, seed or 33)
	return ffi_string(dst, 16)
end

function _M.xxhash128_b64(str, seed)
	local dst1 = get_string_buf(23)
	local dst2 = get_string_buf(16)
	local n = encoding.xxhash128_b64(dst2, dst1, str, #str,  seed or 33)
	return ffi_string(dst1, n), ffi_string(dst2, n)
end

---int_byte convert unsigned int into `4 bytes` with high performance
---@param int_num number @ max number: 21474836479 as `255,255,255,255`
---@param length number @ the char byte length. small number will padding with char(0)
---@return string @ chars based byte, could process by ngx.encode_base64
function _M.uint_byte(int_num, length)
	if not length or length > 3 then
		if int_num > _M.max_int then
			return nil, 'exceed' .. _M.max_int
		end
		return char(band(rshift(int_num, 24), 0xFF), band(rshift(int_num, 16), 0xFF), band(rshift(int_num, 8), 0xFF), band(int_num, 0xFF))
	end
	if length == 3 then
		if int_num > 16777215 then
			return nil, 'exceed 16777215'
		end
		return char(band(rshift(int_num, 16), 0xFF), band(rshift(int_num, 8), 0xFF), band(int_num, 0xFF))
	end
	if length == 2 then
		if int_num > 65535 then
			return nil, 'exceed 65535'
		end
		return char(band(rshift(int_num, 8), 0xFF), band(int_num, 0xFF))
	end
	if int_num > 255 then
		return nil, 'exceed 255'
	end
	return char(int_num)
end

-----int_byte convert unsigned int into `4 bytes`
-----@param int_num number @ max number: 21474836479
-----@return string @ chars based byte, could process by ngx.encode_base64
function _M.int_byte(num)
	return char(band(rshift(num, 24), 0xFF), band(rshift(num, 16), 0xFF), band(rshift(num, 8), 0xFF), band(num, 0xFF))
end

function _M.byte_int(byte_str, start_index)
	if not byte_str then
		return 0
	end
	local len = #byte_str
	if len < 3 then
		return nil, 'at least 4 bytes'
	end
	start_index = start_index or 1
	local n1 = lshift(byte(byte_str, start_index), 24)
	local n2 = lshift(byte(byte_str, start_index + 1), 16)
	local n3 = lshift(byte(byte_str, start_index + 2), 8)
	local n4 = byte(byte_str, start_index + 3) or 0
	return n1 + n2 + n3 + n4
end

_M.max_int_chars = _M.uint_byte(4294967295)

---byte_int convert `4 byte string` into number
---@param byte_str string @char bytes max is `ÿÿÿÿ`
---@return number @ unsigned int max number = 21474836479
---
---byte_uint convert `byte string` into unsigned int
---@param byte_str string
---@param start_index number @ The start index of byte_str stream, start with 1
---@param length number @ the uint length 1-4
function _M.byte_uint(byte_str, start_index, length)
	if not byte_str then
		return 0
	end
	local n = 0
	if not start_index or start_index <= 0 then
		start_index = 0
	else
		start_index = start_index - 1
	end
	--[[
	local len = #byte_str
	for i = 1, len - 1 do
		local bn = byte(byte_str, i)
		local v = lshift(bn, (len - i) * 8)
		n = n + v
	end
	n = n + byte(byte_str, len)
	if n < 0 then
		n = n232 + n
	end--]]
	--n = encoding.get_unsigned_int(byte_str, 0, 1) -- by using c program to speedup
	n = encoding.get_unsigned_int(byte_str, start_index, length or 4) -- by using c program to speedup
	return n
end
---byte_int_from 4 numbers as a byte
---@param a number @[required ]1-255
---@param b number @1-255
---@param c number @1-255
---@param d number @1-255
---@return number
function _M.byte_int_from(a, b, c, d)
	if not a then
		return nil, 'bad input, 1 - 4 int number required'
	end
	return encoding.get_unsigned_int_from(a, b or 0, c or 0, d or 0)
end

---bytes_int_arr
---@param bin_bytes string @[Required]
---@param seed number @[Nullable Default 1] revert number
---@param to_string_format boolean @[Nullable] convert number list into formatted lua table string
function _M.bytes_int_arr(bin_bytes, seed, to_string_format)
	local len = #bin_bytes
	if seed == 0 then
		return nil, 'seed could only greater than zero!'
	end
	seed = seed or 1
	local last = mod(len, 4)
	local arr = new_tab((len - last) / 4, 0)
	local nc = 1
	arr[nc] = len * 99991 -- 199999
	for i = 1, len, 4 do
		nc = nc + 1
		arr[nc] = _M.byte_uint(bin_bytes, i) * seed
	end
	if to_string_format then
		local buff = new_tab(nc, 0)
		local bc = 1
		buff[bc] = '{' .. arr[1] .. ', '
		for i = 2, nc do
			insert(buff, arr[i])
			if i ~= nc then
				if mod(i, 8) == 0 then
					insert(buff, ',')
					insert(buff, '\n')
				else
					insert(buff, ', ')
				end
			end
		end
		insert(buff, '\n}')
		return concat(buff)
	end
	return arr
end

---int_arr_bytes
---@param int_arr number[] @[Required]
---@param seed number @[Nullable Default 1] revert number
function _M.int_arr_bytes(int_arr, seed)
	if not int_arr then
		return
	end
	local len = #int_arr
	if seed == 0 then
		return nil, 'seed could only greater than zero!'
	end
	seed = seed or 1
	local orginal_length = int_arr[1] / 99991
	for i = 2, len do
		int_arr[i] = _M.uint_byte(int_arr[i] / seed)
	end
	local last = mod(orginal_length, 4)
	if last > 0 then
		int_arr[len] = sub(int_arr[len], 1, last)
	end
	table.remove(int_arr, 1)
	return concat(int_arr)
end

---uint_bytes FFI version
---@param unsigned_int number
---@return string
function _M.ffi_uint_bytes(unsigned_int)
	local buff = get_string_buf(4)
	local size = encoding.uint_bytes(buff, unsigned_int)
	return ffi_string(buff, size)
end

---bytes_uint FFI version
---@param byte_buff string
---@param index number @default with 0
---@param length number @ default with whole buff
---@return number
function _M.ffi_bytes_uint(byte_buff, index, length)
	if index then
		index = index - 1
	else
		index = 0
	end
	return tonumber(encoding.bytes_uint(byte_buff, index, length or #byte_buff))
end

---bytes_uint64
---@param byte_buff string
---@param index number @default with 0
---@param length number @ default with whole buff
function _M.bytes_uint64(byte_buff, index, length)
	if index then
		index = index - 1
	else
		index = 0
	end
	return encoding.bytes_uint64(byte_buff, index, length or #byte_buff)
end

---uint64_bytes
---@param num number @ unsigned long long could ffi object
---@return string
function _M.uint64_bytes(num)
	local buff = get_string_buf(8)
	local size = encoding.uint64_bytes(buff, num)
	return ffi_string(buff, size)
end

---xxhash64_bytes hash string into 8 bytes
---@param str string
---@param seed number
---@return string
function _M.xxhash64_bytes(str, seed)
	local num = _M.xxhash64(str, seed)
	return _M.uint64_bytes(num)
end

---xxhash32_bytes hash string into 4 bytes
---@param str string
---@param seed number
---@return string
function _M.xxhash32_bytes(str, seed)
	local num = _M.xxhash32(str, seed)
	return _M.ffi_uint_bytes(num)
end

---list_int_bytes
---@param list number[] @number array
---@param is_unsigned boolean @ indicate is int or unsigned int
---@param sec_length number @bytes list element section length, 1-4
---@return string
function _M.list_int_bytes(list, is_unsigned, sec_length)
	local len = #list
	local arr = array(len)
	if is_unsigned then
		sec_length = sec_length or 4
		if sec_length > 4 then
			return nil, 'section length only less than 4'
		end
		for i = 1, len do
			arr[i] = _M.uint_byte(list[i], sec_length)
		end
	else
		for i = 1, len do
			arr[i] = _M.int_byte(list[i])
		end
	end

	local str = concat(arr)
	release(arr)
	return str
end

---bytes_list_int
---@param bytes string @byte buff
---@param is_unsigned boolean @ indicate is int or unsigned int
---@param sec_length number @bytes list element section length, 1-4
---@return number[]
function _M.bytes_list_int(bytes, is_unsigned, sec_length)
	local len = #bytes
	local arr = new_tab(math.floor(len / 4), 0)
	local nc = 1
	if is_unsigned then
		sec_length = sec_length or 4
		if sec_length > 4 then
			return nil, 'section length only less than 4'
		end
		for i = 1, len, sec_length do
			arr[nc] = _M.byte_uint(bytes, i, sec_length)
			nc = nc + 1
		end
	else
		for i = 1, len, 4 do
			arr[nc] = _M.byte_int(bytes, i)
			nc = nc + 1
		end
	end
	return arr
end

return _M
