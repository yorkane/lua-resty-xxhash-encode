INST_PREFIX ?= /usr
INST_LIBDIR ?= /usr/local/openresty/site/lualib
INST_LUADIR ?= /usr/local/openresty/site/lualib
#INST_LIBDIR ?= $(INST_PREFIX)/lib/lua/5.1
#INST_LUADIR ?= $(INST_PREFIX)/share/lua/5.1
INSTALL ?= install
UNAME ?= $(shell uname)
OR_EXEC ?= $(shell which openresty)
# LUAROCKS_VER ?= $(shell luarocks --version | grep -E -o  "luarocks [0-9]+.")
LUAJIT_DIR ?= $(shell ${OR_EXEC} -V 2>&1 | grep prefix | grep -Eo 'prefix=(.*)/nginx\s+--' | grep -Eo '/.*/')luajit

CFLAGS := -O3 -g -Wall -Wextra -Werror -fpic -Wno-unused-parameter

C_SO_NAME := librestyxxhashencode.so
# LDFLAGS := -shared -L/usr/lib64/ -L/usr/lib/ -L/usr/local/openresty/site/lualib/ -lxxhash -Wl,-rpath,/usr/local/openresty/site/lualib/
LDFLAGS := -shared -L./xxHash -L/usr/lib64/ -L/usr/lib/ -lxxhash

# on Mac OS X, one should set instead:
# for Mac OS X environment, use one of options
ifeq ($(UNAME),Darwin)
	LDFLAGS := -bundle -undefined dynamic_lookup
	C_SO_NAME := librestyradixtree.dylib
endif

MY_CFLAGS := $(CFLAGS) -DBUILDING_SO
MY_LDFLAGS := $(LDFLAGS) -fvisibility=hidden
SRC := $(wildcard src/*.c)
OBJC := $(SRC:.c=.o)
XxhashVersion := 0.7.4

.PHONY: default
default: deps compile

### test:         Run test suite. Use test=... for specific tests
.PHONY: test
test: compile
	TEST_NGINX_LOG_LEVEL=info \
	prove -I../test-nginx/lib -r -s t/


### clean:        Remove generated files
.PHONY: clean
clean:
	rm -f $(C_SO_NAME) $(OBJC)


### compile:      Compile library
.PHONY: compile

compile: $(C_SO_NAME)

#${OBJS} : %.o : %.c
#	cc $(MY_CFLAGS) -c $< -o $@

${C_SO_NAME} : ${OBJC}
	cc $(MY_LDFLAGS) $(OBJC) -o $@


### install:      Install the library to runtime
.PHONY: install
install:
	$(INSTALL) -d $(INST_LUADIR)/resty/
	$(INSTALL) lib/resty/*.lua $(INST_LUADIR)/resty/
	$(INSTALL) $(C_SO_NAME) $(INST_LIBDIR)/



### Downloading xxhash github
.PHONY: deps
deps:
	if [ -d "src/xxHash" ]; then \
        echo "xxHash exists";\
    else\
    	sh install_xxhash.sh;\
    fi



### lint:         Lint Lua source code
.PHONY: lint
lint:
	luacheck -q lib

