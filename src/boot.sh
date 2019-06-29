#!/bin/bash

version_hash=XXXX_VERSION_HASH_XXXX
mulang_source_dir=$HOME/XXXX_MULANG_SOURCE_DIR_XXXX/version-$version_hash

export MULANG_SOURCE_DIR=$mulang_source_dir

if [ ! -e $MULANG_SOURCE_DIR ]; then
    tool_parent_dir=$(dirname $MULANG_SOURCE_DIR)
    if [ ! -e $tool_parent_dir ]; then
        mkdir -p $tool_parent_dir
    fi

    mkdir $MULANG_SOURCE_DIR.tmp 2>/dev/null
    cat $0 | (
        cd $MULANG_SOURCE_DIR.tmp || exit $?
        perl -ne 'print $_ if $f; $f=1 if /^#SOURCE_IMAGE$/' | gzip -n -d -c | bash 2>/dev/null
    )
    mkdir $MULANG_SOURCE_DIR 2>/dev/null && mv $MULANG_SOURCE_DIR.tmp/* $MULANG_SOURCE_DIR/ && rm -rf $MULANG_SOURCE_DIR.tmp
fi

if [ ! -e $MULANG_SOURCE_DIR ]; then
    echo "Not found: $MULANG_SOURCE_DIR" >&2
    exit 1;
fi

bash $MULANG_SOURCE_DIR/main.sh "$@"

exit $?

#SOURCE_IMAGE
