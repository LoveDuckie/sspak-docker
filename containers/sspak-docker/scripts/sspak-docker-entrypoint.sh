#!/bin/bash
<<EOF

	SilverStripe Backup \ Entrypoint

	The entrypoint for the SilverStripe Backup container.

EOF
export CURRENT_SCRIPT_DIRECTORY=$(dirname $(realpath $0))
. "$CURRENT_SCRIPT_DIRECTORY/sspak-docker-functions-logging.sh"

usage() {
    write_info "sspak-docker" "usage - sspak-docker"
    write_info "sspak-docker" "./silverstripe-backup.sh [-t <site target>] [-c <command>] [-b <backup name>] [-h <target host name>] [-r <sites root path>] [-e]"
    exit 1
}

while getopts ":c:h:b:eh?" opt; do
    case $opt in
        c)
            export SSPAK_COMMAND=$OPTARG
            write_info "sspak-docker" "command: \"$SSPAK_COMMAND\""
        ;;
        
        b)
            export BACKUP_NAME=$OPTARG
            write_info "sspak-docker" "backup name: \"$BACKUP_NAME\""
        ;;
        
        h)
            export BACKUP_HOSTNAME=$OPTARG
            write_info "sspak-docker" "hostname: \"$BACKUP_HOSTNAME\""
        ;;
        
        e)
            write_info "sspak-docker" "printing environment variables"
            printenv
        ;;
        
        h | ?)
            usage
        ;;
        
        :)
            write_error "sspak-docker" "invalid option: \"-$OPTARG\" requires an argument"
            exit 1
        ;;
        
        *)
            write_error "sspak-docker" "invalid option: \"-$OPTARG\" is not recognised as an argument"
            exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

. "$CURRENT_SCRIPT_DIRECTORY/sspak-docker-variables.sh"
. "$CURRENT_SCRIPT_DIRECTORY/sspak-docker-functions.sh"

# --------------------------------------------------------------

if [ -z "$SSPAK_COMMAND" ]; then
    write_error "sspak-docker" "sspak command not defined."
    exit 1
fi

if [ -z "$SITE_DOMAIN_NAME" ]; then
    write_error "sspak-docker" "site domain name not defined."
    exit 2
fi

if [ -z "$BACKUP_HOSTNAME" ]; then
    write_warning "sspak-docker" "host name was not defined. using \"$HOSTNAME\" by default."
    BACKUP_HOSTNAME=$HOSTNAME
fi

export HOST_BACKUPS_PATH="$BACKUPS_PATH/$BACKUP_HOSTNAME"

if ! check_installed_tools; then
    write_error "sspak-docker" "required tools are not installed."
    exit 3
fi

if ! check_silverstripe_variables; then
    write_error "sspak-docker" "silverstripe variables not defined"
    exit -1
fi

if ! is_sspak_installed; then
    write_error "sspak-docker" "unable to find sspak cli tool."
    exit 4
fi

if [ -z "$SITES_PATH" ]; then
    write_error "sspak-docker" "sites path not defined (\"SITES_PATH\")."
    exit 5
fi

if [ ! -d "$SITES_PATH" ]; then
    write_error "sspak-docker" "sites path does not exist \"$SITES_PATH\""
    exit 6
fi

if [ -z "$BACKUPS_PATH" ]; then
    write_error "sspak-docker" "backups path was not defined. (\"BACKUPS_PATH\")."
    exit 7
fi

if [ ! -d "$BACKUPS_PATH" ]; then
    write_error "sspak-docker" "backups path does not exist \"$BACKUPS_PATH\"."
    exit 8
fi

if ! is_valid_site $SITE_DOMAIN_NAME; then
    write_error "sspak-docker" "the domain \"$SITE_DOMAIN_NAME\" is not considered valid."
    exit 9
fi

write_info "sspak-docker" "backups path: \"$HOST_BACKUPS_PATH\""

if [ ! -d "$HOST_BACKUPS_PATH" ]; then
    write_info "sspak-docker" "host backups path not found (\"$HOST_BACKUPS_PATH\"). creating."
    mkdir -p "$HOST_BACKUPS_PATH"
    if ! write_response "sspak-docker" "create path \"$HOST_BACKUPS_PATH\""; then
        write_error "sspak-docker" "the host backups path is invalid or null"
        exit 10
    fi
fi

exit 0

# --------------------------------------------------------------

case $SSPAK_COMMAND in
    restore)
        if [ -z "$BACKUP_NAME" ]; then
            write_warning "sspak-docker" "no backup filename defined. attempting to restore latest."
            
            if ! restore_latest_backup; then
                write_error "sspak-docker" "failed to restore latest backup"
                exit 1
            fi
            
            exit 0
        fi
        
        if ! restore_backup $BACKUP_NAME; then
            write_error "sspak-docker" "unable to restore backup (\"$BACKUP_NAME\")"
            exit 2
        fi
        
        write_success "sspak-docker" "restored: \"$BACKUP_NAME\""
    ;;
    
    backup)
        write_info "sspak-docker" "creating backup for \"$SITE_DOMAIN_NAME\""
        write_info "sspak-docker" "backup path: \"$HOST_BACKUPS_PATH/$SITE_DOMAIN_NAME\""
        
        if ! create_backup "$SITE_DOMAIN_NAME"; then
            write_error "sspak-docker" "failed to create backup for \"$SITE_DOMAIN_NAME\""
            exit 1
        fi
        
        write_success "sspak-docker" "created backup for \"$SITE_DOMAIN_NAME\""
    ;;
    
    *)
        write_info "sspak-docker" "the command \"$SSPAK_COMMAND\" was not recognized. unable to continue."
        usage
    ;;
esac

write_success "sspak-docker" "done"
exit 0
