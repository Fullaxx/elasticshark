#!/bin/bash

set -e

# -std=c99
CFLAGS="-Wall -ansi"
CFLAGS+=" -DUSE_GETLINE"
OPTCFLAGS="${CFLAGS} -O2"
DBGCFLAGS="${CFLAGS} -ggdb3 -DDEBUG"

rm -f *.exe *.dbg

gcc ${OPTCFLAGS}         main.c ek2es7.c cJSON.c -o ek2es7.exe
gcc ${DBGCFLAGS}         main.c ek2es7.c cJSON.c -o ek2es7.dbg
gcc ${OPTCFLAGS} -static main.c ek2es7.c cJSON.c -o ek2es7.static.exe

gcc ${OPTCFLAGS}         main.c pretty.c cJSON.c -o pretty.exe
gcc ${DBGCFLAGS}         main.c pretty.c cJSON.c -o pretty.dbg
gcc ${OPTCFLAGS} -static main.c pretty.c cJSON.c -o pretty.static.exe

strip *.exe
