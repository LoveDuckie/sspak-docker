#!/bin/bash
<<EOF

  SilverStripe Backup \ Functions

  Shared functions that are used for performing various operations for SilverStripe backup container.

EOF
[ -n "${SILVERSTRIPEBACKUP_SHARED_FUNCTIONS}" ] && return
SILVERSTRIPEBACKUP_SHARED_FUNCTIONS=0

is_sspak_installed() {
    if [ "$(command -v sspak)" == "" ]; then
        return 1
    fi

    return 0
}

is_cronjob_added() {
    if [ ! -e "$CRONJOB_FILEPATH" ]; then
        write_error "add-cronjob" "failed to locate the script to be run at intervals."
        return 1
    fi

    return 0
}

is_valid_site_target() {
    if [ -z "$1" ]; then
        write_error "silverstripebackup-functions" "the site target was not defined."
        return 1
    fi

    if [ ! -d "$SITES_ROOT_PATH/$1" ]; then
        write_error "silverstripebackup-functions" "unable to find \"$1\" in \"$SITES_ROOT_PATH\""
        return 2
    fi

    return 0
}

add_cronjob() {
    if [ ! -e "$CRONJOB_FILEPATH" ]; then
        write_error "add-cronjob" "unable to find \"$CRONJOB_FILEPATH\"."
        return 1
    fi

    CRON_DEFINITION="0 0 * * * /bin/bash -c \"$CRONJOB_FILEPATH\" 1> /backup-logs/silverstripe-backup-log-\$(date +%Y-%m-%d_%H-%M-%S).log 2> /backup-logs/silverstripe-backup-errors-\$(date +%Y-%m-%d_%H-%M-%S).log"

    write_info "silverstripebackup-entrypoint" "using schedule defined as \"$BACKUP_CRON_SCHEDULE\""
    echo $CRON_DEFINITION | sudo tee /etc/crontabs/root
    if ! write_response "add-cronjob" "add cronjob definition to crontab for \"$(whoami)\""; then
        return 1
    fi

    return 0
}

get_latest_backup() {
    local BACKUPS_HOST_SITE_TARGET_PATH="$BACKUPS_PATH_HOST/$SITE_TARGET"

    if [ -z "$2" ]; then
        write_warning "silverstripebackup-functions" "the target site to retrieve the latest backup for was not found. using \"$SITE_TARGET\" by default."
    fi

    write_info "get-latest-backup" "retrieving latest backup for \"$SITE_TARGET\""

    if [ -z "$BACKUPS_HOST_SITE_TARGET_PATH" ]; then
        write_error "silverstripebackup-functions" "the path to the backups was not defined (\"BACKUPS_HOST_SITE_TARGET_PATH\")."
        return 1
    fi

    if [ ! -d "$BACKUPS_HOST_SITE_TARGET_PATH" ]; then
        write_error "get-latest-backup" "\"$BACKUPS_HOST_SITE_TARGET_PATH\" does not exist."
        return 2
    fi

    if [ -z "$1" ]; then
        write_error "get-latest-backup" "the variable for returning the latest backup filepath with was not defined."
        return 3
    fi

    eval "$1=$(find $(realpath $BACKUPS_HOST_SITE_TARGET_PATH) -type f \( -name "${BACKUP_FILENAME_PREFIX}*.sspak" -and -not -name '*latest*' \) | sort -r | head -n 1)"

    if ! write_response "get-latest-backup" "find latest backup in \"$BACKUPS_HOST_SITE_TARGET_PATH\""; then
        return 4
    fi

    return 0
}

create_backup() {
    if ! is_sspak_installed; then
        write_error "silverstripebackup - create-backup" "failed to find sspak on the commandline."
        return 2
    fi

    local TARGET_SITE"=$1"
    local SITE_TARGET_BACKUPS_PATH="$BACKUPS_PATH_HOST/$TARGET_SITE"

    if [ ! -d "$SITE_TARGET_BACKUPS_PATH" ]; then
        write_warning "silverstripebackup - create-backup" "\"$SITE_TARGET_BACKUPS_PATH\" does not exist. creating."
        mkdir -p "$SITE_TARGET_BACKUPS_PATH"
        write_response "silverstripebackup - create-backup" "create \"$SITE_TARGET_BACKUPS_PATH\""
    fi

    # TARGET_FILENAME_SUFFIX=$(date +%Y-%m-%d_%H-%M-%S)
    # TARGET_FILENAME="$BACKUP_FILENAME-$(echo $TARGET_SITE | sed -E 's/([^a-zA-Z]+)/_/g')"
    TARGET_FILENAME="$BACKUP_FILENAME"
    write_info "silverstripebackup - create-backup" "website: \"$TARGET_SITE\""

    TARGET_FILENAME_FORMATTED=${TARGET_FILENAME}

    write_info "silverstripebackup - create-backup" "backup name: \"$TARGET_FILENAME_FORMATTED\""
    sspak save "$SITES_ROOT_PATH/$TARGET_SITE" "$SITE_TARGET_BACKUPS_PATH/$TARGET_FILENAME_FORMATTED".sspak
    if ! write_response "silverstripebackup - create-backup" "sspak save backup: $TARGET_FILENAME_FORMATTED"; then
        return 1
    fi

    if [[ ! -z "$DELETE_EXCESS_BACKUPS" ]]; then
        if ! delete_excess_backups; then
            write_error "silverstripebackup - create-backup" "failed to delete excess backups"
            return 1
        fi
    fi

    if [[ -n "$UPDATE_LATEST" ]]; then
        write_info "silverstripebackup - create-backup" "updating latest backup in \"$BACKUPS_PATH_HOST\""
        if ! update_latest_backup "$BACKUPS_PATH_HOST"; then
            write_error "silverstripebackup - create-backup" "failed to update the latest backup"
            return 1
        fi
    fi

    return 0
}

create_all_backups() {
    if [ "$(command -v sspak)" == "" ]; then
        write_error "create-all-backups" "failed to find sspak on the commandline."
        return 2
    fi

    for target in ${SITES_TARGETS[@]}; do
        write_info "create-all-backups" "backing up \"$target\""

        if ! create_backup $target; then
            write_error "create-all-backups" "failed: unable to create backup for \"$target\""
            continue
        fi

        write_success "create-all-backups" "created backup \"$target\""
    done

    return 0
}

delete_excess_backups() {
    write_info "silverstripebackup - delete-excess-backups" "deleting excess backups from \"$BACKUPS_PATH_HOST\""
    find $(realpath $BACKUPS_PATH_HOST) \( -name "${BACKUP_FILENAME_PREFIX}*.sspak" -and -not -name '*latest*' \) | sort | grep -v '/$' | head -n -$MAX_BACKUPS | xargs -I {} rm -- {}

    if ! write_response "silverstripebackup - delete-excess-backups" "delete excess backups in \"$BACKUPS_PATH_HOST\""; then
        write_error "silverstripebackup-functions" "failed to delete excess backups in \"$BACKUPS_PATH_HOST\""
        return 1
    fi

    write_success "silverstripebackup - delete-excess-backups" "successfully deleted excess backups in \"$BACKUPS_PATH_HOST\""
    return 0
}

check_installed_tools() {
    for command in ${SSPAK_TOOLS_REQUIRED[@]}; do
        if [ "$(command -v $command)" == "" ]; then
            write_error "silverstripebackup-entrypoint" "the command \"$command\" is not available. make sure required dependencies are installed."
            return 1
        fi
    done

    return 0
}

update_latest_backup() {
    local LATEST_BACKUP_FOUND=''

    if ! get_latest_backup LATEST_BACKUP_FOUND $SITE_TARGET; then
        write_error "silverstripebackup - update-latest-backup" "failed to find the latest backup for site target \"$1\""
        return 1
    fi

    if [ -z "$LATEST_BACKUP_FOUND" ]; then
        write_info "silverstripebackup - update-latest-backup" "no recent backup was found under \"$BACKUPS_PATH_HOST\""
        return 2
    fi

    write_info "silverstripebackup - update-latest-backup" "found \"$(basename $LATEST_BACKUP_FOUND)\" as the latest backup"

    local BACKUPS_HOST_SITE_TARGET_PATH="$BACKUPS_PATH_HOST/$SITE_TARGET"

    local LATEST_BACKUP_METADATA_FILEPATH=$BACKUPS_HOST_SITE_TARGET_PATH/${BACKUP_FILENAME_PREFIX}backup.latest
    local LATEST_BACKUP_FILENAME=${BACKUP_FILENAME_PREFIX}latest.sspak
    local LATEST_BACKUP_FILEPATH=$BACKUPS_HOST_SITE_TARGET_PATH/$LATEST_BACKUP_FILENAME

    if [ -e "$LATEST_BACKUP_METADATA_FILEPATH" ]; then
        write_warning "silverstripebackup - update-latest-backup" "\"$LATEST_BACKUP_METADATA_FILEPATH\" exists. deleting."
        rm -f "$LATEST_BACKUP_METADATA_FILEPATH"

        if ! write_response "silverstripebackup - update-latest-backup" "delete latest backup metadata file"; then
            return 3
        fi

        write_success "silverstripebackup - update-latest-backup" "deleted \"$LATEST_BACKUP_METADATA_FILEPATH\""
    fi

    write_info "silverstripebackup - update-latest-backup" "updating latest backup metadata file"
    write_info "silverstripebackup - update-latest-backup" "latest backup: \"$LATEST_BACKUP_FOUND\""
    echo "$(basename $LATEST_BACKUP_FOUND)" | sudo tee -a "$LATEST_BACKUP_METADATA_FILEPATH" >/dev/null 2>&1

    if [ -e "$LATEST_BACKUP_FILEPATH" ]; then
        write_warning "silverstripebackup - update-latest-backup" "\"$LATEST_BACKUP_FILEPATH\" already exists. deleting."
        rm -f "$LATEST_BACKUP_FILEPATH"
    fi

    if [ -z "$LATEST_BACKUP_FOUND" ]; then
        write_error "silverstripebackup - update-latest-backup" "unable to find the latest backup."
        return 4
    fi

    write_info "silverstripebackup - update-latest-backup" "copying \"$LATEST_BACKUP_FOUND\" to \"$LATEST_BACKUP_FILENAME\""
    cp "$LATEST_BACKUP_FOUND" "$LATEST_BACKUP_FILEPATH"
    write_response "silverstripebackup - update-latest-backup" "copying \"$LATEST_BACKUP_FOUND\" to \"$LATEST_BACKUP_FILENAME\""

    write_info "silverstripebackup - update-latest-backup" "the latest backup is now \"$(basename $LATEST_BACKUP_FOUND)\""

    # write_info "silverstripebackup - update-latest-backup" "updating file ownership in \"$BACKUPS_PATH_HOST\""
    # sudo chown -R :appuser "$BACKUPS_PATH_HOST" > /dev/null 2>&1
    # write_response "silverstripebackup - update-latest-backup" "update file permissions in \"$BACKUPS_PATH_HOST\""

    write_info "silverstripebackup - update-latest-backup" "updating file permissions in \"$BACKUPS_PATH_HOST\""
    sudo chmod -R ug+rwx "$BACKUPS_PATH_HOST" >/dev/null 2>&1
    write_response "silverstripebackup - update-latest-backup" "update file permissions: \"$BACKUPS_PATH_HOST\""

    write_success "silverstripebackup - update-latest-backup" "completed updating the latest backup"
    return 0
}

restore_latest_backup() {
    if [ -z "$SITE_TARGET" ]; then
        write_error "restore-latest-backup" "the site target was not defined."
        return 1
    fi

    local LATEST_BACKUP_FILEPATH=''

    if ! get_latest_backup LATEST_BACKUP_FILEPATH; then
        write_error "restore-latest-backup" "failed to retrieve the latest backup"
        return 2
    fi

    if [ -z "$LATEST_BACKUP_FILEPATH" ]; then
        write_info "restore-latest-backup" "the filepath to the latest backup is empty or null"
        return 3
    fi

    if [ ! -e "$LATEST_BACKUP_FILEPATH" ]; then
        write_info "restore-latest-backup" "the backup file \"$LATEST_BACKUP_FILEPATH\" does not exist."
    fi

    write_info "restore-latest-backup" "restoring: \"$LATEST_BACKUP_FILEPATH\""
    sspak load "$LATEST_BACKUP_FILEPATH" "$SITES_ROOT_PATH/$SITE_TARGET" --drop-db

    if ! write_response "restore-latest-backup" "load the database backup from \"$LATEST_BACKUP_FILEPATH\""; then
        return 4
    fi

    return 0
}

restore_backup() {
    if [ -z "$1" ]; then
        write_error "silverstripebackup-functions" "the backup filepath to restore was not defined."
        return 1
    fi

    local BACKUPS_HOST_SITE_TARGET_PATH="$BACKUPS_PATH_HOST/$SITE_TARGET"

    BACKUP_FILEPATH=$BACKUPS_HOST_SITE_TARGET_PATH/$1

    if [ ! -e $BACKUP_FILEPATH ]; then
        write_error "silverstripebackup-functions" "unable to find \"$BACKUP_FILEPATH\""
        return 2
    fi

    write_warning "silverstripebackup-functions" "restoring: \"$BACKUP_FILEPATH\""
    sspak load "$BACKUP_FILEPATH" "$SITES_ROOT_PATH/$SITE_TARGET" --drop-db

    if ! write_response "silverstripebackup-functions" "restore: \"$BACKUP_FILEPATH\""; then
        return 3
    fi

    return 0
}

export -f check_installed_tools
export -f restore_latest_backup
export -f restore_backup
export -f update_latest_backup
export -f delete_excess_backups
export -f create_all_backups
export -f create_backup
export -f get_latest_backup
