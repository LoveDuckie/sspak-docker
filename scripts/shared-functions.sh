#!/bin/bash
<<EOF

    SSPAK Docker \ Shared Functions

    A collection of shared functions used in various places.

EOF
[ -n "${SHARED_FUNCTIONS_SSPAK}" ] && return
SHARED_FUNCTIONS_SSPAK=0
CURRENT_SCRIPT_DIRECTORY_FUNCTIONS=$(dirname $(realpath $0))
export SHARED_EXT_SCRIPTS_PATH=$(realpath ${SHARED_EXT_SCRIPTS_PATH:-$CURRENT_SCRIPT_DIRECTORY_FUNCTIONS})
export REPO_ROOT_PATH=${REPO_ROOT_PATH:-$(realpath $SHARED_EXT_SCRIPTS_PATH/../)}
# . "$SHARED_EXT_SCRIPTS_PATH/shared-variables.sh"

unset -f write_info
unset -f write_error
unset -f write_debug
unset -f write_warning
unset -f write_critical
unset -f write_response

write_response() {
    if [ $? -ne 0 ]; then
        write_error "error" "$2"
        return 1
    fi
    
    write_success "success" "$2"
    return 0
}

write_info() {
    MSG=$2
    echo -e "\e[1;36m$1\e[0m \e[0;37m${MSG}\e[0m" 1>&2
    return 0
}

write_success() {
    MSG=$2
    echo -e "\e[1;32m$1\e[0m \e[0;37m${MSG}\e[0m" 1>&2
    return 0
}

write_error() {
    MSG=$2
    echo -e "\e[1;31m$1\e[0m \e[0;37m${MSG}\e[0m" 1>&2
    return 0
}

write_critical() {
    MSG=$2
    echo -e "\e[1;31;5m$1\e[0m \e[0;37m${MSG}\e[0m" 1>&2
    return 0
}

write_warning() {
    MSG=$2
    echo -e "\e[1;33m$1\e[0m \e[0;37m${MSG}\e[0m" 1>&2
    return 0
}

export -f write_response
export -f write_info
export -f write_warning
export -f write_critical
export -f write_error
export -f write_success