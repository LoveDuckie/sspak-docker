#!/bin/bash
<<EOF

	SilverStripe Backup \ Entrypoint

	The entrypoint for the SilverStripe Backup container.

EOF
export CURRENT_SCRIPT_DIRECTORY=$(dirname $(realpath $0))
. "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-functions-logging.sh"

usage() {
    write_info "silverstripebackup" "usage - silverstripebackup"
    write_info "silverstripebackup" "./silverstripe-backup.sh [-t <site target>] [-c <command>] [-b <backup name>] [-h <target host name>] [-r <sites root path>] [-e]"
    exit 1
}

while getopts ":c:h:b:eh?" opt; do
    case $opt in        
        c)
            export SSPAK_COMMAND=$OPTARG
            write_info "silverstripebackup" "command: \"$SSPAK_COMMAND\""
        ;;
        
        b)
            export BACKUP_NAME=$OPTARG
            write_info "silverstripebackup" "backup name: \"$BACKUP_NAME\""
        ;;
        
        h)
            export BACKUP_HOSTNAME=$OPTARG
            write_info "silverstripebackup" "hostname: \"$BACKUP_HOSTNAME\""
        ;;
        
        e)
            write_info "silverstripebackup" "printing environment variables"
            printenv
        ;;
        
        h | ?)
            usage
        ;;
        
        :)
            write_error "silverstripebackup" "invalid option: \"-$OPTARG\" requires an argument"
            exit 1
        ;;
        
        *)
            write_error "silverstripebackup" "invalid option: \"-$OPTARG\" is not recognised as an argument"
            exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

. "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-variables.sh"
. "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-functions.sh"

# --------------------------------------------------------------

if [ -z "$SSPAK_COMMAND" ]; then
    write_error "silverstripebackup" "sspak command not defined."
    exit 1
fi

if [ -z "$SITE_DOMAIN_NAME" ]; then
    write_error "silverstripebackup" "site domain name not defined."
    exit 2
fi

if [ -z "$BACKUP_HOSTNAME" ]; then
    write_warning "silverstripebackup" "host name was not defined. using \"$HOSTNAME\" by default."
    BACKUP_HOSTNAME=$HOSTNAME
fi

export HOST_BACKUPS_PATH="$BACKUPS_PATH/$BACKUP_HOSTNAME"

if ! check_installed_tools; then
    write_error "silverstripebackup" "required tools are not installed."
    exit 3
fi

if ! check_silverstripe_variables; then
	write_error "silverstripebackup-entrypoint" "silverstripe variables not defined"
	exit -1
fi

if ! is_sspak_installed; then
    write_error "silverstripebackup" "unable to find sspak cli tool."
    exit 4
fi

if [ -z "$SITES_PATH" ]; then
    write_error "silverstripebackup" "sites path not defined (\"SITES_PATH\")."
    exit 5
fi

if [ ! -d "$SITES_PATH" ]; then
    write_error "silverstripebackup" "sites path does not exist \"$SITES_PATH\""
    exit 6
fi

if [ -z "$BACKUPS_PATH" ]; then
    write_error "silverstripebackup" "backups path was not defined. (\"BACKUPS_PATH\")."
    exit 7
fi

if [ ! -d "$BACKUPS_PATH" ]; then
    write_error "silverstripebackup" "backups path does not exist \"$BACKUPS_PATH\"."
    exit 8
fi

if ! is_valid_site $SITE_DOMAIN_NAME; then
    write_error "silverstripebackup" "the domain \"$SITE_DOMAIN_NAME\" is not considered valid."
    exit 9
fi

write_info "silverstripebackup" "backups path: \"$HOST_BACKUPS_PATH\""

if [ ! -d "$HOST_BACKUPS_PATH" ]; then
    write_info "silverstripebackup" "host backups path not found (\"$HOST_BACKUPS_PATH\"). creating."
    mkdir -p "$HOST_BACKUPS_PATH"
    if ! write_response "silverstripebackup" "create path \"$HOST_BACKUPS_PATH\""; then
        write_error "silverstripebackup-entrypoint" "the host backups path is invalid or null"
        exit 10
    fi
fi

exit 0

# --------------------------------------------------------------

case $SSPAK_COMMAND in
    restore)
        if [ -z "$BACKUP_NAME" ]; then
            write_warning "silverstripebackup" "no backup filename defined. attempting to restore latest."
            
            if ! restore_latest_backup; then
                write_error "silverstripebackup" "failed to restore latest backup"
                exit 1
            fi
            
            exit 0
        fi
        
        if ! restore_backup $BACKUP_NAME; then
            write_error "silverstripebackup" "unable to restore backup (\"$BACKUP_NAME\")"
            exit 2
        fi
        
        write_success "silverstripebackup" "restored: \"$BACKUP_NAME\""
    ;;
    
    backup)
        write_info "silverstripebackup" "creating backup for \"$SITE_DOMAIN_NAME\""
        write_info "silverstripebackup" "backup path: \"$HOST_BACKUPS_PATH/$SITE_DOMAIN_NAME\""
        
        if ! create_backup "$SITE_DOMAIN_NAME"; then
            write_error "silverstripebackup" "failed to create backup for \"$SITE_DOMAIN_NAME\""
            exit 1
        fi
        
        write_success "silverstripebackup" "created backup for \"$SITE_DOMAIN_NAME\""
    ;;
    
    *)
        write_info "silverstripebackup" "the command \"$SSPAK_COMMAND\" was not recognized. unable to continue."
        usage
    ;;
esac

write_success "silverstripebackup" "done"
exit 0
