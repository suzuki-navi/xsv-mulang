#!/bin/bash

set -Ceu
# -C リダイレクトでファイルを上書きしない
# -e コマンドの終了コードが1つでも0以外になったら直ちに終了する
# -u 設定されていない変数が参照されたらエラー

: "${MULANG_SOURCE_PARENT_DIR_NAME:=.xsvutils/mulang}"

: "$MULANG_SOURCE_DIR"
# MULANG_SOURCE_DIR はmulangでビルド時に定義される。
# 未定義の場合にエラーとする。

if [ ! -e var ]; then
    mkdir var
    echo "*" > var/.gitignore
fi

mkdir -p var/target

target_sources_1=$(cd src; ls)
target_sources_2=$(echo $(for f in $target_sources_1; do echo $f; done | sed 's#^#var/target/#g'))

target_bin_1=$(cd src; ls *.mulang.conf 2>/dev/null | sed 's/\.mulang\.conf$//g')
target_bin_2=$(echo $(for f in $target_bin_1; do echo $f; done | sed 's#^#var/target/#g'))

########################################
# makefileを作成
########################################

(

    cat <<EOF
var/out.sh: var/TARGET_VERSION_HASH
	cat $MULANG_SOURCE_DIR/boot.sh | sed "s/XXXX_VERSION_HASH_XXXX/\$\$(cat var/TARGET_VERSION_HASH)/g" | sed "s#XXXX_MULANG_SOURCE_DIR_XXXX#$MULANG_SOURCE_PARENT_DIR_NAME#g" > var/out.sh.tmp
	(cd var/target; perl $MULANG_SOURCE_DIR/pack-dir.pl) > var/image.sh
	(cd var/target; perl $MULANG_SOURCE_DIR/pack-dir.pl) | gzip -n -c >> var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF

    for f in $target_sources_1; do
        cat <<EOF
var/target/$f: src/$f var/target/.dir
	cp src/$f var/target/$f

EOF
    done

for f in $target_bin_1;do
    perl $MULANG_SOURCE_DIR/build-bin-make.pl $f
done

    cat <<EOF
var/target/.anylang: var/target/.dir
	curl -fsS https://raw.githubusercontent.com/xsvutils/xsv-anylang/master/anylang.sh > var/target/.anylang.tmp
	chmod +x var/target/.anylang.tmp
	mv var/target/.anylang.tmp var/target/.anylang

var/target/.dir:
	mkdir -p var/target
	touch var/target/.dir

var/TARGET_VERSION_HASH: $target_sources_2 $target_bin_2 var/target/.anylang
	cat \$\$(find var/target -type f | LC_ALL=C sort) | shasum | cut -b1-40 > var/TARGET_VERSION_HASH.tmp
	mv var/TARGET_VERSION_HASH.tmp var/TARGET_VERSION_HASH

EOF

) >| var/makefile.tmp
mv var/makefile.tmp var/makefile

########################################
# var/target にある不要なファイルを削除
# ソースコードが減った場合、リネームされた場合に備えた処理
########################################

RM_TARGET=$(diff -u \
            <( (echo .; echo ..; echo .anylang; echo .dir; for f in $target_sources_1; do echo $f; done; for f in $target_bin_1; do echo $f; echo ".$f-bin"; done;) | LC_ALL=C sort ) \
            <( cd var/target; ls -a | LC_ALL=C sort ) |
                tail -n+3 | grep '^\+' | cut -b2-)

if [ -n "$RM_TARGET" ]; then
    for f in $RM_TARGET; do
        echo rm -r var/target/$f >&2
        rm -r var/target/$f >&2
    done
fi

########################################
# make を実行
########################################

make -f var/makefile "$@"

exit $?

########################################

