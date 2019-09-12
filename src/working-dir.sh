
create_soft_working_dir() {
    if [ -z "$UID" ]; then
        UID=$(id -u)
    fi
    if [ -d /run/user/$UID ]; then
        export MULANG_SOFT_WORKING_DIR=$(mktemp -d /run/user/$UID/mulang-XXXXXXXX)
    elif [ -d /dev/shm ]; then
        export MULANG_SOFT_WORKING_DIR=$(mktemp -d /dev/shm/mulang-XXXXXXXX)
    else
        export MULANG_SOFT_WORKING_DIR=$(mktemp -d /tmp/mulang-XXXXXXXX)
    fi
    [ -n "$MULANG_SOFT_WORKING_DIR" ] || { echo "Cannot create MULANG_SOFT_WORKING_DIR: $MULANG_SOFT_WORKING_DIR"; exit $?; }
}

create_hard_working_dir() {
    export MULANG_HARD_WORKING_DIR=$(mktemp -d /tmp/mulang-hard-XXXXXXXX)
    [ -n "$MULANG_HARD_WORKING_DIR" ] || { echo "Cannot create MULANG_HARD_WORKING_DIR: $MULANG_HARD_WORKING_DIR"; exit $?; }
}

export MULANG_SOFT_WORKING_DIR=""
export MULANG_HARD_WORKING_DIR=""

#create_soft_working_dir
#create_hard_working_dir

trap "rm -rf $MULANG_SOFT_WORKING_DIR $MULANG_HARD_WORKING_DIR" EXIT

