echo Hello
cat $MULANG_SOURCE_DIR/data.bin | gzip -n -d -c
$MULANG_SOURCE_DIR/test1
$MULANG_SOURCE_DIR/test2
$MULANG_SOURCE_DIR/test3

(
    /usr/bin/time $MULANG_SOURCE_DIR/test1
    /usr/bin/time $MULANG_SOURCE_DIR/test2
    /usr/bin/time $MULANG_SOURCE_DIR/test3
) >&2
