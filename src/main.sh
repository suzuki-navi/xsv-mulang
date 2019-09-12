#!/bin/bash

set -Ceu
# -C リダイレクトでファイルを上書きしない
# -e コマンドの終了コードが1つでも0以外になったら直ちに終了する
# -u 設定されていない変数が参照されたらエラー

development_mode=

while [ "$#" != 0 ]; do
    case "$1" in
        --devel )
            development_mode=1
            ;;
        * )
            echo "Option \`${1}\` is not supported." >&1
            exit 1
            ;;
    esac
    shift
done

MULANG_SOURCE_PARENT_DIR_NAME="${MULANG_SOURCE_PARENT_DIR_NAME:-.xsvutils/mulang}"

: "$MULANG_SOURCE_DIR"
# MULANG_SOURCE_DIR はmulangでビルド時に定義される。
# 未定義の場合にエラーとする。

# ターゲットプロジェクトの開発用ビルド
export MULANG_DEVELOPMENT_MODE="$development_mode"

if [ ! -e var ]; then
    mkdir var
    echo "*" > var/.gitignore
fi

if [ -e var/last_mode ]; then
    if [ "$(cat var/last_mode)" != "$development_mode" ]; then
        rm var/last_mode
    fi
fi

mkdir -p var/target

########################################
# main.sh をチェック
########################################

if [ ! -e src/main.sh ]; then
    echo "not found: src/main.sh" >&2
    exit 1
fi

use_soft_working_dir=
use_hard_working_dir=
if grep "MULANG_SOFT_WORKING_DIR" src/main.sh; then
    # `MULANG_SOFT_WORKING_DIR` という文字列が src/main.sh に含まれる場合
    use_soft_working_dir=1
fi
if grep "MULANG_HARD_WORKING_DIR" src/main.sh; then
    # `MULANG_HARD_WORKING_DIR` という文字列が src/main.sh に含まれる場合
    use_hard_working_dir=1
fi

########################################
# ソースファイルの一覧
########################################

target_sources_1=$(cd src; ls)
target_sources_2=$(echo $(for f in $target_sources_1; do echo $f; done | sed 's#^#var/target/#g'))

target_bin_1=$(cd src; ls *.mulang.conf 2>/dev/null | sed 's/\.mulang\.conf$//g')
target_bin_2=$(echo $(for f in $target_bin_1; do echo $f; done | sed 's#^#var/target/#g'))

########################################
# makefileを作成
########################################

(

    if [ -n "$use_soft_working_dir" -o -n "$use_hard_working_dir" ]; then
        if [ -n "$development_mode" ]; then
            # 開発時用ビルド
            # シングルバイナリにはしない
            pwd=$(pwd)
            cat <<EOF
var/out.sh: var/TARGET_VERSION_HASH var/last_mode var/target/.working-dir.sh
	echo "#!/bin/bash" > var/out.sh.tmp
	echo ". var/target/.working-dir.sh" >> var/out.sh.tmp
	echo "MULANG_SOURCE_DIR=$pwd/var/target bash $pwd/var/target/main.sh \"\\\$\$@\"" >> var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF
        else
            # リリース版用ビルド
            cat <<EOF
var/out.sh: var/TARGET_VERSION_HASH var/last_mode var/target/.working-dir.sh
	cat $MULANG_SOURCE_DIR/boot.sh | sed "s/XXXX_VERSION_HASH_XXXX/\$\$(cat var/TARGET_VERSION_HASH)/g" | sed "s#XXXX_MULANG_SOURCE_DIR_XXXX#$MULANG_SOURCE_PARENT_DIR_NAME#g" | sed 's#^\\#working_dir\$\$#. \$\$MULANG_SOURCE_DIR/.working-dir.sh#g' > var/out.sh.tmp
	(cd var/target; perl $MULANG_SOURCE_DIR/pack-dir.pl) > var/image.sh
	(cd var/target; perl $MULANG_SOURCE_DIR/pack-dir.pl) | gzip -n -c >> var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF
        fi
    else
        if [ -n "$development_mode" ]; then
            # 開発時用ビルド
            # シングルバイナリにはしない
            pwd=$(pwd)
            cat <<EOF
var/out.sh: var/TARGET_VERSION_HASH var/last_mode
	echo "MULANG_SOURCE_DIR=$pwd/var/target bash $pwd/var/target/main.sh \"\\\$\$@\"" > var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF
        else
            # リリース版用ビルド
            cat <<EOF
var/out.sh: var/TARGET_VERSION_HASH var/last_mode
	cat $MULANG_SOURCE_DIR/boot.sh | sed "s/XXXX_VERSION_HASH_XXXX/\$\$(cat var/TARGET_VERSION_HASH)/g" | sed "s#XXXX_MULANG_SOURCE_DIR_XXXX#$MULANG_SOURCE_PARENT_DIR_NAME#g" > var/out.sh.tmp
	(cd var/target; perl $MULANG_SOURCE_DIR/pack-dir.pl) > var/image.sh
	(cd var/target; perl $MULANG_SOURCE_DIR/pack-dir.pl) | gzip -n -c >> var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF
        fi
    fi

    cat <<EOF
FORCE:

var/last_mode:
	echo "$development_mode" > var/last_mode

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

    dotfiles=".anylang"
    if [ -n "$use_soft_working_dir" -o -n "$use_hard_working_dir" ]; then
        dotfiles="$dotfiles .working-dir.sh"
    fi

    # var/target にある不要なファイルを削除
    # ソースコードが減った場合、リネームされた場合に備えた処理
    rm_targets=$(echo $(echo $dotfiles; echo .dir; for f in $target_sources_1; do echo $f; done; for f in $target_bin_1; do echo $f; echo ".$f-bin"; done))
    cd var/target
    if bash $MULANG_SOURCE_DIR/rm-targets.sh $rm_targets; then
        rm_targets_flag=
    else
        rm_targets_flag=FORCE
    fi
    cd ../..

    cat <<EOF
var/target/.anylang: var/target/.dir
	curl -fsS https://raw.githubusercontent.com/xsvutils/xsv-anylang/master/anylang.sh > var/target/.anylang.tmp
	chmod +x var/target/.anylang.tmp
	mv var/target/.anylang.tmp var/target/.anylang

EOF

    if [ -n "$use_soft_working_dir" -a -n "$use_hard_working_dir" ]; then
        cat <<EOF
var/target/.working-dir.sh: var/target/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_soft_working_dir\$\$/create_soft_working_dir/g' | sed 's/^#create_hard_working_dir\$\$/create_hard_working_dir/g' > var/target/.working-dir.sh.tmp
	mv var/target/.working-dir.sh.tmp var/target/.working-dir.sh

EOF
    elif [ -n "$use_soft_working_dir" ]; then
        cat <<EOF
var/target/.working-dir.sh: var/target/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_soft_working_dir\$\$/create_soft_working_dir/g' > var/target/.working-dir.sh.tmp
	mv var/target/.working-dir.sh.tmp var/target/.working-dir.sh

EOF
    elif [ -n "$use_hard_working_dir" ]; then
        cat <<EOF
var/target/.working-dir.sh: var/target/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_hard_working_dir\$\$/create_hard_working_dir/g' > var/target/.working-dir.sh.tmp
	mv var/target/.working-dir.sh.tmp var/target/.working-dir.sh

EOF
    fi

    cat <<EOF
var/target/.dir:
	mkdir -p var/target
	touch var/target/.dir

var/TARGET_VERSION_HASH: $target_sources_2 $target_bin_2 var/target/.anylang $rm_targets_flag
	(find var/target -type f | LC_ALL=C sort; cat \$\$(find var/target -type f | LC_ALL=C sort)) | shasum | cut -b1-40 > \$@.tmp
	if [ ! -e \$@ ] || ! cmp -s \$@.tmp \$@; then mv \$@.tmp \$@; fi

EOF

) >| var/makefile.tmp
mv var/makefile.tmp var/makefile

########################################
# make を実行
########################################

make --question -f var/makefile || make -f var/makefile "$@"

exit $?

########################################

