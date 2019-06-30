
rm_targets=$(diff -u \
     <( (
         echo .
         echo ..
         for f in "$@"; do
             echo $f
         done
     ) | LC_ALL=C sort ) \
     <( ls -a | LC_ALL=C sort ) |
     tail -n+3 | grep '^\+' | cut -b2-)

if [ -n "$rm_targets" ]; then
    for f in $rm_targets; do
        echo rm -r $f >&2
        rm -r $f >&2
    done
    exit 1
fi

exit 0

