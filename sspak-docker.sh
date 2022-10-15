#!/bin/bash
<<EOF

   SSPAK \ Docker



EOF
CURRENT_SCRIPT_DIRECTORY=${CURRENT_SCRIPT_DIRECTORY:-$(dirname $(realpath $0))}
export SHARED_SSPAK_SCRIPTS_PATH=${SHARED_SSPAK_SCRIPTS_PATH:-$(realpath $CURRENT_SCRIPT_DIRECTORY/scripts)}
export CURRENT_SCRIPT_FILENAME=${CURRENT_SCRIPT_FILENAME:-$(basename $0)}
export CURRENT_SCRIPT_FILENAME_BASE=${CURRENT_SCRIPT_FILENAME%.*}
. "$SHARED_SSPAK_SCRIPTS_PATH/shared-functions.sh"
write_header

usage() {
   exit -1
}

while getopts ':h?' opt; do
    case $opt in
        h|?)
            usage
        ;;
        :)
            write_error "sspak-docker" "\"-${OPTARG}\" requires an argument"
            usage
        ;;
        *)
            write_error "sspak-docker" "\"-${OPTARG}\" was not recognised"
            usage
        ;;
    esac
done

write_info "sspak-docker" "running sspak"

write_success "sspak-docker" "done"