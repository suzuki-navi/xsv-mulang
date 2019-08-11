echo Hello
cat $MULANG_SOURCE_DIR/data.bin | gzip -n -d -c
$MULANG_SOURCE_DIR/test1 foo
$MULANG_SOURCE_DIR/test2 bar
$MULANG_SOURCE_DIR/test3 baz

(
    /usr/bin/time $MULANG_SOURCE_DIR/test1
    /usr/bin/time $MULANG_SOURCE_DIR/test2
    /usr/bin/time $MULANG_SOURCE_DIR/test3
) >&2
