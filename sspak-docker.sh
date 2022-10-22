#!/bin/bash
<<EOF

    SSPAK \ Docker

    Entrypoint for running SSPAK in a Docker container.

EOF
CURRENT_SCRIPT_DIRECTORY=${CURRENT_SCRIPT_DIRECTORY:-$(dirname $(realpath $0))}
export SHARED_SSPAK_SCRIPTS_PATH=${SHARED_SSPAK_SCRIPTS_PATH:-$(realpath $CURRENT_SCRIPT_DIRECTORY/scripts)}
export CURRENT_SCRIPT_FILENAME=${CURRENT_SCRIPT_FILENAME:-$(basename $0)}
export CURRENT_SCRIPT_FILENAME_BASE=${CURRENT_SCRIPT_FILENAME%.*}
. "$SHARED_SSPAK_SCRIPTS_PATH/shared-functions.sh"
write_header

usage() {
    write_info "sspak-docker" "usage - sspak-docker"
    write_info "sspak-docker" "sspak-docker.sh [-c <docker context name>] [-e <configuration environment>] [-o <sspak command>] [-h or -?]"
    exit -1
}

while getopts ':c:e:o:h?' opt; do
    case $opt in
        c)
            DOCKER_CONTEXT_NAME=$OPTARG
            write_warning "sspak-docker" "using docker context \"$DOCKER_CONTEXT_NAME\""
        ;;
        e)
            CONFIGURATION_ENVIRONMENT=$OPTARG
            write_warning "sspak-docker" "using configuration environment \"$CONFIGURATION_ENVIRONMENT\""
        ;;
        o)
            SSPAK_COMMAND=$OPTARG
            write_warning "sspak-docker" "running command \"$SSPAK_COMMAND\""
        ;;
        h|?)
            usage
        ;;
        :)
            write_error "sspak-docker" "\"-${OPTARG}\" requires an argument"
            usages
        ;;
        *)
            write_error "sspak-docker" "\"-${OPTARG}\" was not recognised"
            usage
        ;;
    esac
done

if [ -z "$SSPAK_COMMAND" ]; then
    write_error "sspak-docker" "sspak command not defined (\"SSPAK_COMMAND\")"
    exit 1
fi

if [ -z "$CONFIGURATION_ENVIRONMENT" ]; then
    write_warning "sspak-docker" "configuration environment not defined. using \"development\" by default."
    CONFIGURATION_ENVIRONMENT=development
fi

if [ ! -z $DOCKER_CONTEXT_NAME ]; then
    write_warning "sspak-docker" "using docker context \"$DOCKER_CONTEXT_NAME\""
    DOCKER_CONTEXT_ARGS=" --context \"$DOCKER_CONTEXT_NAME\""
fi

write_info "sspak-docker" "running sspak"
CONFIGURATION_FILENAME=docker-compose.$CONFIGURATION_ENVIRONMENT.yaml
export BACKUP_HOSTNAME=$HOSTNAME

write_info "sspak-docker" "running sspak docker"
RUN_ARGS="docker-compose${DOCKER_CONTEXT_ARGS} -f docker-compose.yaml -f $CONFIGURATION_FILENAME run --rm sspak-docker"
write_info "sspak-docker" "running: \"$RUN_ARGS\""
$RUN_ARGS
if ! write_response "sspak-docker" "run sspak docker: \"$SSPAK_COMMAND\""; then
    write_error "sspak-docker" "failed to run \"$SSPAK_COMMAND\""
    exit 1
fi

write_success "sspak-docker" "done"
exit 0