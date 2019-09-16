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

mkdir -p var/target-single
mkdir -p var/target-devel

########################################
# main.sh をチェック
########################################

if [ ! -e src/main.sh ]; then
    echo "not found: src/main.sh" >&2
    exit 1
fi

use_soft_working_dir=
use_hard_working_dir=
if grep "MULANG_SOFT_WORKING_DIR" src/main.sh >/dev/null; then
    # `MULANG_SOFT_WORKING_DIR` という文字列が src/main.sh に含まれる場合
    use_soft_working_dir=1
fi
if grep "MULANG_HARD_WORKING_DIR" src/main.sh >/dev/null; then
    # `MULANG_HARD_WORKING_DIR` という文字列が src/main.sh に含まれる場合
    use_hard_working_dir=1
fi

########################################
# ソースファイルの一覧
########################################

target_sources_1=$(cd src; ls)
target_sources_single=$(echo $(for f in $target_sources_1; do echo $f; done | sed 's#^#var/target-single/#g'))
target_sources_devel=$(echo $(for f in $target_sources_1; do echo $f; done | sed 's#^#var/target-devel/#g'))

target_bin_1=$(cd src; ls *.mulang.conf 2>/dev/null | sed 's/\.mulang\.conf$//g')
target_bin_single=$(echo $(for f in $target_bin_1; do echo $f; done | sed 's#^#var/target-single/#g'))
target_bin_devel=$(echo $(for f in $target_bin_1; do echo $f; done | sed 's#^#var/target-devel/#g'))

########################################
# makefileを作成
########################################

(

    cat <<EOF
build: var/out.sh

EOF

    if [ -n "$use_soft_working_dir" -o -n "$use_hard_working_dir" ]; then

        # 開発時用ビルド
        # シングルバイナリにはしない
        pwd=$(pwd)
        cat <<EOF
var/out-devel.sh: var/TARGET_DEVEL_VERSION_HASH
	echo "#!/bin/bash" > var/out-devel.sh.tmp
	echo ". var/target-devel/.working-dir.sh" >> var/out-devel.sh.tmp
	echo "MULANG_SOURCE_DIR=$pwd/var/target-devel bash $pwd/var/target-devel/main.sh \"\\\$\$@\"" >> var/out-devel.sh.tmp
	chmod 755 var/out-devel.sh.tmp
	mv var/out-devel.sh.tmp var/out-devel.sh

EOF

        # リリース版用ビルド
        cat <<EOF
var/out.sh: var/TARGET_SINGLE_VERSION_HASH
	cat $MULANG_SOURCE_DIR/boot.sh | sed "s/XXXX_VERSION_HASH_XXXX/\$\$(cat var/TARGET_SINGLE_VERSION_HASH)/g" | sed "s#XXXX_MULANG_SOURCE_DIR_XXXX#$MULANG_SOURCE_PARENT_DIR_NAME#g" | sed 's#^\\#working_dir\$\$#. \$\$MULANG_SOURCE_DIR/.working-dir.sh#g' > var/out.sh.tmp
	(cd var/target-single; perl $MULANG_SOURCE_DIR/pack-dir.pl) > var/image.sh
	(cd var/target-single; perl $MULANG_SOURCE_DIR/pack-dir.pl) | gzip -n -c >> var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF

    else

        # 開発時用ビルド
        # シングルバイナリにはしない
        pwd=$(pwd)
        cat <<EOF
var/out-devel.sh: var/TARGET_DEVEL_VERSION_HASH
	echo "MULANG_SOURCE_DIR=$pwd/var/target-devel bash $pwd/var/target-devel/main.sh \"\\\$\$@\"" > var/out-devel.sh.tmp
	chmod 755 var/out-devel.sh.tmp
	mv var/out-devel.sh.tmp var/out-devel.sh

EOF

        # リリース版用ビルド
        cat <<EOF
var/out.sh: var/TARGET_SINGLE_VERSION_HASH
	cat $MULANG_SOURCE_DIR/boot.sh | sed "s/XXXX_VERSION_HASH_XXXX/\$\$(cat var/TARGET_SINGLE_VERSION_HASH)/g" | sed "s#XXXX_MULANG_SOURCE_DIR_XXXX#$MULANG_SOURCE_PARENT_DIR_NAME#g" > var/out.sh.tmp
	(cd var/target-single; perl $MULANG_SOURCE_DIR/pack-dir.pl) > var/image.sh
	(cd var/target-single; perl $MULANG_SOURCE_DIR/pack-dir.pl) | gzip -n -c >> var/out.sh.tmp
	chmod 755 var/out.sh.tmp
	mv var/out.sh.tmp var/out.sh

EOF

    fi

    cat <<EOF
FORCE:

EOF

    for f in $target_sources_1; do
        cat <<EOF
var/target-single/$f: src/$f var/target-single/.dir
	cp src/$f var/target-single/$f

EOF
    done
    for f in $target_sources_1; do
        cat <<EOF
var/target-devel/$f: src/$f var/target-devel/.dir
	cp src/$f var/target-devel/$f

EOF
    done

    for f in $target_bin_1;do
        perl $MULANG_SOURCE_DIR/build-bin-make.pl $f
    done

    dotfiles=".anylang"
    if [ -n "$use_soft_working_dir" -o -n "$use_hard_working_dir" ]; then
        dotfiles+=" .working-dir.sh"
    fi
    dotfiles_target_single=
    dotfiles_target_devel=
    for f in $dotfiles; do
        dotfiles_target_single+=" var/target-single/$f"
        dotfiles_target_devel+=" var/target-devel/$f"
    done

    # var/target にある不要なファイルを削除
    # ソースコードが減った場合、リネームされた場合に備えた処理
    rm_targets=$(echo $(echo $dotfiles; echo .dir; for f in $target_sources_1; do echo $f; done; for f in $target_bin_1; do echo $f; echo ".$f-bin"; done))
    if (cd var/target-single; bash $MULANG_SOURCE_DIR/rm-targets.sh $rm_targets); then
        rm_targets_single_flag=
    else
        rm_targets_single_flag=FORCE
    fi
    if (cd var/target-devel; bash $MULANG_SOURCE_DIR/rm-targets.sh $rm_targets); then
        rm_targets_devel_flag=
    else
        rm_targets_devel_flag=FORCE
    fi

    cat <<EOF
var/target-single/.anylang: var/target-single/.dir
	curl -fsS https://raw.githubusercontent.com/xsvutils/xsv-anylang/master/anylang.sh > var/target-single/.anylang.tmp
	chmod +x var/target-single/.anylang.tmp
	mv var/target-single/.anylang.tmp var/target-single/.anylang

var/target-devel/.anylang: var/target-devel/.dir var/target-single/.anylang
	cp var/target-single/.anylang var/target-devel/.anylang

EOF

    if [ -n "$use_soft_working_dir" -a -n "$use_hard_working_dir" ]; then
        cat <<EOF
var/target-single/.working-dir.sh: var/target-single/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_soft_working_dir\$\$/create_soft_working_dir/g' | sed 's/^#create_hard_working_dir\$\$/create_hard_working_dir/g' > var/target-single/.working-dir.sh.tmp
	mv var/target-single/.working-dir.sh.tmp var/target-single/.working-dir.sh

var/target-devel/.working-dir.sh: var/target-devel/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_soft_working_dir\$\$/create_soft_working_dir/g' | sed 's/^#create_hard_working_dir\$\$/create_hard_working_dir/g' > var/target-devel/.working-dir.sh.tmp
	mv var/target-devel/.working-dir.sh.tmp var/target-devel/.working-dir.sh

EOF
    elif [ -n "$use_soft_working_dir" ]; then
        cat <<EOF
var/target-single/.working-dir.sh: var/target-single/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_soft_working_dir\$\$/create_soft_working_dir/g' > var/target-single/.working-dir.sh.tmp
	mv var/target-single/.working-dir.sh.tmp var/target-single/.working-dir.sh

var/target-devel/.working-dir.sh: var/target-devel/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_soft_working_dir\$\$/create_soft_working_dir/g' > var/target-devel/.working-dir.sh.tmp
	mv var/target-devel/.working-dir.sh.tmp var/target-devel/.working-dir.sh

EOF
    elif [ -n "$use_hard_working_dir" ]; then
        cat <<EOF
var/target-single/.working-dir.sh: var/target-single/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_hard_working_dir\$\$/create_hard_working_dir/g' > var/target-single/.working-dir.sh.tmp
	mv var/target-single/.working-dir.sh.tmp var/target-single/.working-dir.sh

var/target-devel/.working-dir.sh: var/target-devel/.dir src/main.sh
	cat $MULANG_SOURCE_DIR/working-dir.sh | sed 's/^#create_hard_working_dir\$\$/create_hard_working_dir/g' > var/target-devel/.working-dir.sh.tmp
	mv var/target-devel/.working-dir.sh.tmp var/target-devel/.working-dir.sh

EOF
    fi

    cat <<EOF
var/target-single/.dir:
	mkdir -p var/target-single
	touch var/target-single/.dir

var/target-devel/.dir:
	mkdir -p var/target-devel
	touch var/target-devel/.dir

var/TARGET_SINGLE_VERSION_HASH: $target_sources_single $target_bin_single $dotfiles_target_single $rm_targets_single_flag
	(find var/target-single -type f | LC_ALL=C sort; cat \$\$(find var/target-single -type f | LC_ALL=C sort)) | shasum | cut -b1-40 > \$@.tmp
	if [ ! -e \$@ ] || ! cmp -s \$@.tmp \$@; then mv \$@.tmp \$@; fi

var/TARGET_DEVEL_VERSION_HASH: $target_sources_devel $target_bin_devel $dotfiles_target_devel $rm_targets_devel_flag
	(find var/target-devel -type f | LC_ALL=C sort; cat \$\$(find var/target-devel -type f | LC_ALL=C sort)) | shasum | cut -b1-40 > \$@.tmp
	if [ ! -e \$@ ] || ! cmp -s \$@.tmp \$@; then mv \$@.tmp \$@; fi

EOF

) >| var/makefile.tmp
mv var/makefile.tmp var/makefile

########################################
# make を実行
########################################

target=var/out.sh
if [ -n "$development_mode" ]; then
    target=var/out-devel.sh
fi

make --question -f var/makefile $target || make -f var/makefile $target

exit $?

########################################

