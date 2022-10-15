#!/bin/bash
<<EOF

  SilverStripe Backup \ Functions

  Shared functions that are used for performing various operations for SilverStripe backup container.

EOF
[ -n "${SILVERSTRIPEBACKUP_SHARED_FUNCTIONS}" ] && return
SILVERSTRIPEBACKUP_SHARED_FUNCTIONS=0

unset -f is_sspak_installed
unset -f is_valid_site
unset -f get_latest_backup
unset -f create_backup
unset -f delete_excess_backups
unset -f check_installed_tools
unset -f update_latest_backup
unset -f restore_latest_backup
unset -f restore_backup

is_sspak_installed() {
    if [ "$(command -v sspak)" == "" ]; then
        return 1
    fi

    return 0
}

is_valid_site() {
    if [ -z "$1" ]; then
        write_error "silverstripebackup" "site domain name not specified."
        return 1
    fi

    SITE_PATH="$SITES_PATH/$1"
    if [ ! -d "$SITE_PATH" ]; then
        write_error "silverstripebackup" "unable to site \"$1\" (\"$SITE_PATH\")"
        return 2
    fi

    return 0
}

get_latest_backup() {
    local BACKUPS_HOST_SITE_DOMAIN_PATH="$HOST_BACKUPS_PATH/$SITE_DOMAIN"

    if [ -z "$2" ]; then
        write_warning "silverstripebackup" "website not defined. using \"$SITE_DOMAIN\" by default."
    fi

    if [ -z "$BACKUPS_HOST_SITE_DOMAIN_PATH" ]; then
        write_error "silverstripebackup" "the path to the backups was not defined (\"BACKUPS_HOST_SITE_DOMAIN_PATH\")."
        return 1
    fi

    if [ ! -d "$BACKUPS_HOST_SITE_DOMAIN_PATH" ]; then
        write_error "silverstripebackup" "\"$BACKUPS_HOST_SITE_DOMAIN_PATH\" does not exist."
        return 2
    fi

    if [ -z "$1" ]; then
        write_error "silverstripebackup" "the variable for returning the latest backup filepath with was not defined."
        return 3
    fi

    eval "$1=$(find $(realpath $BACKUPS_HOST_SITE_DOMAIN_PATH) -type f \( -name "${BACKUP_FILENAME_PREFIX}*.sspak" -and -not -name '*latest*' \) | sort -r | head -n 1)"

    if ! write_response "silverstripebackup" "find latest backup in \"$BACKUPS_HOST_SITE_DOMAIN_PATH\""; then
        return 4
    fi

    return 0
}

create_backup() {
    if ! is_sspak_installed; then
        write_error "silverstripebackup" "failed to find sspak on the commandline."
        return 2
    fi

    local TARGET_SITE_DOMAIN_NAME"=$1"
    local SITE_BACKUPS_PATH="$HOST_BACKUPS_PATH/$TARGET_SITE_DOMAIN_NAME"

    if [ ! -d "$SITE_BACKUPS_PATH" ]; then
        write_warning "silverstripebackup" "\"$SITE_BACKUPS_PATH\" does not exist. creating."
        mkdir -p "$SITE_BACKUPS_PATH"
        write_response "silverstripebackup" "create \"$SITE_BACKUPS_PATH\""
    fi

    # TARGET_FILENAME_SUFFIX=$(date +%Y-%m-%d_%H-%M-%S)
    # TARGET_FILENAME="$BACKUP_FILENAME-$(echo $TARGET_SITE_DOMAIN_NAME | sed -E 's/([^a-zA-Z]+)/_/g')"
    TARGET_FILENAME="$BACKUP_FILENAME"
    write_info "silverstripebackup" "website: \"$TARGET_SITE_DOMAIN_NAME\""

    TARGET_FILENAME_FORMATTED=${TARGET_FILENAME}

    write_info "silverstripebackup" "backup name: \"$TARGET_FILENAME_FORMATTED\""
    sspak save "$SITES_PATH/$TARGET_SITE_DOMAIN_NAME" "$SITE_BACKUPS_PATH/$TARGET_FILENAME_FORMATTED".sspak
    if ! write_response "silverstripebackup" "sspak save backup: \"$TARGET_FILENAME_FORMATTED\""; then
        write_error "silverstripebackup" "failed to save backup \"$TARGET_FILENAME_FORMATTED\""
        return 1
    fi

    if [[ ! -z "$DELETE_EXCESS_BACKUPS" ]]; then
        if ! delete_excess_backups; then
            write_error "silverstripebackup" "failed to delete excess backups"
            return 2
        fi
    fi

    if [[ -n "$UPDATE_LATEST" ]]; then
        write_info "silverstripebackup" "updating latest backup in \"$HOST_BACKUPS_PATH\""
        if ! update_latest_backup "$HOST_BACKUPS_PATH"; then
            write_error "silverstripebackup" "failed to update the latest backup"
            return 3
        fi
    fi

    return 0
}

delete_excess_backups() {
    write_info "silverstripebackup" "deleting excess backups from \"$HOST_BACKUPS_PATH\""
    find $(realpath $HOST_BACKUPS_PATH) \( -name "${BACKUP_FILENAME_PREFIX}*.sspak" -and -not -name '*latest*' \) | sort | grep -v '/$' | head -n -$MAX_BACKUPS | xargs -I {} rm -- {}

    if ! write_response "silverstripebackup" "delete excess backups in \"$HOST_BACKUPS_PATH\""; then
        write_error "silverstripebackup" "failed to delete excess backups in \"$HOST_BACKUPS_PATH\""
        return 1
    fi

    write_success "silverstripebackup" "successfully deleted excess backups in \"$HOST_BACKUPS_PATH\""
    return 0
}

check_installed_tools() {
    for command in ${SSPAK_TOOLS_REQUIRED[@]}; do
        if [ "$(command -v $command)" == "" ]; then
            write_error "silverstripebackup" "the command \"$command\" is not available. make sure required dependencies are installed."
            return 1
        fi
    done

    return 0
}

check_silverstripe_variables() {
    for silverstripe_variable in ${SILVERSTRIPE_VARS[@]}; do
        if [ -z `echo \\$$var_name` ]; then
            write_error "silverstripebackup-functions" "\"$silverstripe_variable\" is not defined"
            exit 1
        fi
    done

    return 0
}

update_latest_backup() {
    local LATEST_BACKUP_FOUND=''

    if ! get_latest_backup LATEST_BACKUP_FOUND $SITE_DOMAIN; then
        write_error "silverstripebackup" "failed to find the latest backup for site target \"$1\""
        return 1
    fi

    if [ -z "$LATEST_BACKUP_FOUND" ]; then
        write_info "silverstripebackup" "no recent backup found in \"$HOST_BACKUPS_PATH\""
        return 2
    fi

    write_info "silverstripebackup" "found \"$(basename $LATEST_BACKUP_FOUND)\" as the latest backup"

    local BACKUPS_HOST_SITE_DOMAIN_PATH="$HOST_BACKUPS_PATH/$SITE_DOMAIN"

    local LATEST_BACKUP_METADATA_FILEPATH=$BACKUPS_HOST_SITE_DOMAIN_PATH/${BACKUP_FILENAME_PREFIX}backup.latest
    local LATEST_BACKUP_FILENAME=${BACKUP_FILENAME_PREFIX}latest.sspak
    local LATEST_BACKUP_FILEPATH=$BACKUPS_HOST_SITE_DOMAIN_PATH/$LATEST_BACKUP_FILENAME

    if [ -e "$LATEST_BACKUP_METADATA_FILEPATH" ]; then
        write_warning "silverstripebackup" "\"$(basename $LATEST_BACKUP_METADATA_FILEPATH)\" exists. deleting."
        rm -f "$LATEST_BACKUP_METADATA_FILEPATH"

        if ! write_response "silverstripebackup" "delete latest backup metadata file"; then
            return 3
        fi

        write_success "silverstripebackup" "deleted \"$(basename $LATEST_BACKUP_METADATA_FILEPATH)\""
    fi

    write_info "silverstripebackup" "latest backup: \"$(basename $LATEST_BACKUP_FOUND)\""
    echo "$(basename $LATEST_BACKUP_FOUND)" | sudo tee -a "$LATEST_BACKUP_METADATA_FILEPATH" >/dev/null 2>&1

    if [ -e "$LATEST_BACKUP_FILEPATH" ]; then
        write_warning "silverstripebackup" "\"$(basename $LATEST_BACKUP_FILEPATH)\" already exists. deleting."
        rm -f "$LATEST_BACKUP_FILEPATH"
    fi

    if [ -z "$LATEST_BACKUP_FOUND" ]; then
        write_error "silverstripebackup" "unable to find the latest backup."
        return 4
    fi

    write_info "silverstripebackup" "copying \"$LATEST_BACKUP_FOUND\" to \"$LATEST_BACKUP_FILENAME\""
    cp "$LATEST_BACKUP_FOUND" "$LATEST_BACKUP_FILEPATH"
    write_response "silverstripebackup" "copying \"$LATEST_BACKUP_FOUND\" to \"$LATEST_BACKUP_FILENAME\""

    write_info "silverstripebackup" "the latest backup is now \"$(basename $LATEST_BACKUP_FOUND)\""

    # write_info "silverstripebackup" "updating file ownership in \"$HOST_BACKUPS_PATH\""
    # sudo chown -R :appuser "$HOST_BACKUPS_PATH" > /dev/null 2>&1
    # write_response "silverstripebackup" "update file permissions in \"$HOST_BACKUPS_PATH\""

    write_info "silverstripebackup" "updating file permissions in \"$HOST_BACKUPS_PATH\""
    sudo chmod -R ug+rwx "$HOST_BACKUPS_PATH" >/dev/null 2>&1
    write_response "silverstripebackup" "update file permissions: \"$HOST_BACKUPS_PATH\""

    write_success "silverstripebackup" "completed updating the latest backup"
    return 0
}

restore_latest_backup() {
    if [ -z "$SITE_DOMAIN" ]; then
        write_error "silverstripebackup" "the site target was not defined."
        return 1
    fi

    local LATEST_BACKUP_FILEPATH=''

    if ! get_latest_backup LATEST_BACKUP_FILEPATH; then
        write_error "silverstripebackup" "failed to retrieve the latest backup"
        return 2
    fi

    if [ -z "$LATEST_BACKUP_FILEPATH" ]; then
        write_info "silverstripebackup" "the filepath to the latest backup is empty or null"
        return 3
    fi

    if [ ! -e "$LATEST_BACKUP_FILEPATH" ]; then
        write_info "silverstripebackup" "the backup file \"$LATEST_BACKUP_FILEPATH\" does not exist."
    fi

    write_info "silverstripebackup" "restoring: \"$(basename $LATEST_BACKUP_FILEPATH)\""
    sspak load "$LATEST_BACKUP_FILEPATH" "$SITES_PATH/$SITE_DOMAIN" --drop-db
    if ! write_response "silverstripebackup" "restore backup from \"$(basename $LATEST_BACKUP_FILEPATH)\""; then
        write_error "silverstripebackup" "failed to restore backup from \"$(basename $LATEST_BACKUP_FILEPATH)\""
        return 4
    fi

    return 0
}

restore_backup() {
    if [ -z "$1" ]; then
        write_error "silverstripebackup" "the backup to restore was not defined."
        return 1
    fi

    local BACKUPS_HOST_SITE_DOMAIN_PATH="$HOST_BACKUPS_PATH/$SITE_DOMAIN"

    BACKUP_FILEPATH=$BACKUPS_HOST_SITE_DOMAIN_PATH/$1

    if [ ! -e $BACKUP_FILEPATH ]; then
        write_error "silverstripebackup" "unable to find \"$BACKUP_FILEPATH\""
        return 2
    fi

    write_warning "silverstripebackup" "restoring: \"$BACKUP_FILEPATH\""
    sspak load "$BACKUP_FILEPATH" "$SITES_PATH/$SITE_DOMAIN" --drop-db

    if ! write_response "silverstripebackup" "restore: \"$BACKUP_FILEPATH\""; then
        return 3
    fi

    return 0
}

export -f is_sspak_installed
export -f is_valid_site
export -f get_latest_backup
export -f create_backup
export -f delete_excess_backups
export -f check_installed_tools
export -f update_latest_backup
export -f restore_latest_backup
export -f restore_backup