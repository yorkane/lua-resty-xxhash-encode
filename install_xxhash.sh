#!/usr/bin/env bash
XxhashVersion='0.7.3'
rm -rf src/xxHash
echo "Downloading https://github.com/Cyan4973/xxHash/archive/v${XxhashVersion}.tar.gz -Lk | tar -xvz -C src/"
curl https://github.com/Cyan4973/xxHash/archive/v${XxhashVersion}.tar.gz -Lk | tar -xvz -C src/
mv src/xxHash* src/xxHash
cd src/xxHash
make && make install