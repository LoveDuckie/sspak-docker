#!/bin/bash
<<EOF

  SilverStripe Backup \ Entrypoint

  The entrypoint for the SilverStripe Backup container.

EOF
export CURRENT_SCRIPT_DIRECTORY=$(dirname $(realpath $0))
source "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-functions-logging.sh"

usage() {
  write_info "silverstripebackup" "usage - silverstripebackup-entrypoint"
  write_info "silverstripebackup" "[-t <site target>] [-c <command>] [-b <backup name>] [-h <target host name>] [-r <sites root path>] [-e]"
  exit 1
}

while getopts ":c:t:h:b:r:eh?" opt; do
  case $opt in
  t)
    export SITE_TARGET=$OPTARG
    write_info "silverstripebackup" "target site: \"$SITE_TARGET\""
    ;;

  c)
    export SSPAK_COMMAND=$OPTARG
    write_info "silverstripebackup" "command recognized: \"$SSPAK_COMMAND\""
    ;;

  b)
    export TARGET_BACKUP=$OPTARG
    write_info "silverstripebackup" "target backup: \"$TARGET_BACKUP\""
    ;;

  h)
    export TARGET_HOSTNAME=$OPTARG
    write_info "silverstripebackup" "target hostname: \"$TARGET_HOSTNAME\""
    ;;

  r)
    export SITES_ROOT_PATH=$OPTARG
    write_info "silverstripebackup" "sites root path: \"$SITES_ROOT_PATH\""
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

source "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-shared-variables.sh"
source "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-functions.sh"

# --------------------------------------------------------------

if [ -z "$SSPAK_COMMAND" ]; then
  write_error "silverstripebackup" "the command was not defined. unable to continue."
  exit 1
fi

if [ -z "$SITE_TARGET" ]; then
  write_error "silverstripebackup" "the site target specifid is empty or invalid. unable to continue."
  exit 2
fi

if [ -z "$TARGET_HOSTNAME" ]; then
  write_warning "silverstripebackup" "target host name was not defined, or is empty. using \"$HOSTNAME\" by default."
  TARGET_HOSTNAME=$HOSTNAME
fi

export BACKUPS_PATH_HOST="$BACKUPS_PATH/$TARGET_HOSTNAME"

if ! check_installed_tools; then
  write_error "silverstripebackup" "required tools are not installed on this system."
  exit 3
fi

if ! is_sspak_installed; then
  write_error "silverstripebackup" "failed: unable to find sspak cli tool."
  exit 4
fi

if [ -z "$SITES_ROOT_PATH" ]; then
  write_error "silverstripebackup" "the absolute path to where the contents of the site was not defined (\"SITES_ROOT_PATH\")."
  exit 5
fi

if [ ! -d "$SITES_ROOT_PATH" ]; then
  write_error "silverstripebackup" "the path \"$SITES_ROOT_PATH\" does not exist."
  exit 6
fi

if [ -z "$BACKUPS_PATH" ]; then
  write_error "silverstripebackup" "the target path for where backups are to be stored was not defined (\"BACKUPS_PATH\")."
  exit 7
fi

if [ ! -d "$BACKUPS_PATH" ]; then
  write_error "silverstripebackup" "failed to find \"$BACKUPS_PATH\" in container."
  exit 8
fi

if ! is_valid_site_target $SITE_TARGET; then
  write_error "silverstripebackup" "the domain \"$SITE_TARGET\" is not considered valid."
  exit 9
fi

write_info "silverstripebackup" "backups path: \"$BACKUPS_PATH_HOST\""

if [ ! -d "$BACKUPS_PATH_HOST" ]; then
  write_info "silverstripebackup" "the path \"$BACKUPS_PATH_HOST\" was not found. creating."
  mkdir -p "$BACKUPS_PATH_HOST"
  write_response "silverstripebackup" "create path \"$BACKUPS_PATH_HOST\""
fi

# --------------------------------------------------------------

case $SSPAK_COMMAND in
restore)
  if [ -z "$TARGET_BACKUP" ]; then
    write_warning "silverstripebackup" "no backup filename was defined. restoring latest."

    if ! restore_latest_backup; then
      write_error "silverstripebackup" "failed to restore latest backup"
      exit 1
    fi

    exit 0
  fi

  if ! restore_backup $TARGET_BACKUP; then
    write_error "silverstripebackup" "failed: unable to restore backup (\"$TARGET_BACKUP\")"

    exit 1
  fi

  write_success "silverstripebackup" "successfully restored: \"$TARGET_BACKUP\""
  ;;

backup)
  write_info "silverstripebackup" "creating backup for \"$SITE_TARGET\""
  write_info "silverstripebackup" "backup path: \"$BACKUPS_PATH_HOST/$SITE_TARGET\""

  if ! create_backup "$SITE_TARGET"; then
    write_error "silverstripebackup" "failed to create backup for \"$SITE_TARGET\""
    exit 1
  fi

  write_success "silverstripebackup" "created backup for \"$SITE_TARGET\""
  ;;

backup-cron)
  write_info "silverstripebackup" "setting up cron job for backups"

  if [[ -n "$BACKUP_CRON_SCHEDULE" ]]; then
    write_error "silverstripebackup" "the cron schedule was not defined. check the \"BACKUP_CRON_SCHEDULE\" variable and try again."
    exit 1
  fi

  write_response "silverstripebackup" "cron schedule: \"$BACKUP_CRON_SCHEDULE\""

  if ! add_cronjob; then
    write_error "silverstripebackup" "failed: unable to add cronjob scheduled \"$BACKUP_CRON_SCHEDULE\""
    exit 2
  fi

  if ! is_cronjob_added; then
    write_error "silverstripebackup" "failed: unable to find cronjob in system configuration"
    exit 3
  fi

  write_success "silverstripebackup" "successfully added cronjob."
  crond -f -l 8
  write_response "silverstripebackup" "display crontab"

  write_info "silverstripebackup" "sleeping"
  sleep infinity
  ;;

*)
  write_info "silverstripebackup" "the command \"$SSPAK_COMMAND\" was not recognized. unable to continue."
  usage
  ;;
esac

write_success "silverstripebackup" "done"
