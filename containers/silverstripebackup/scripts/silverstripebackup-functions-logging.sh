#!/bin/bash
<<EOF

  SilverStripe Backup \ Functions \ Logging

  Shared functions that are used for performing various operations for SilverStripe backup container.

EOF
[ -n "${SILVERSTRIPEBACKUP_SHARED_FUNCTIONS_LOGGING}" ] && return
SILVERSTRIPEBACKUP_SHARED_FUNCTIONS_LOGGING=0

unset -f write_info
unset -f write_warning
unset -f write_success
unset -f write_error
unset -f write_response

write_info() {
    MSG=$2
    echo -e "\e[1;36m$1\e[0m \e[1;37m${MSG}\e[0m" 1>&2
}

write_success() {
    MSG=$2
    echo -e "\e[1;32m$1\e[0m \e[1;37m${MSG}\e[0m" 1>&2
}

write_error() {
    MSG=$2
    echo -e "\e[1;31m$1\e[0m \e[1;37m${MSG}\e[0m" 1>&2
}

write_warning() {
    MSG=$2
    echo -e "\e[1;33m$1\e[0m \e[1;37m${MSG}\e[0m" 1>&2
}

write_response() {
    if [ $? -eq 0 ]; then
        write_success "success" "$2"
    else
        write_error "failed" "$2"
        exit 1
    fi

    return 0
}

export -f write_info
export -f write_warning
export -f write_success
export -f write_error
export -f write_response
