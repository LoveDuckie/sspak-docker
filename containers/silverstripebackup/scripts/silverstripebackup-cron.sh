#!/bin/bash
<<EOF

    SilverStripe Backup \ Shared \ Variables

    A collection of shared variables that are used around the container.
    
EOF
CURRENT_SCRIPT_DIRECTORY=${CURRENT_SCRIPT_DIRECTORY:-$(dirname $(realpath $0))}
source "$CURRENT_SCRIPT_DIRECTORY/silverstripebackup-functions.sh"

BACKUPS_PATH="/mnt/backups"
DB_RESTORE_TARGET="/mnt/backups"
BACKUP_FILENAME="silverstripe_backup"
SITES_ROOT_PATH_DOMAIN="lucshelton.com"
SITES_ROOT_PATH_DOMAINS=(lucshelton.com)
SITES_RESTORE_TARGET="/var/www/sites/$SITES_ROOT_PATH_DOMAIN"
SITES_ROOT_PATH="/var/www/sites"

if ! update-latest-backup; then
    write_error "silverstripebackup-cron" "failed to update silverstripe backups"
    exit 1
fi

if ! create_all_backups; then
    write_error "silverstripebackup-cron" "failed to create backups for \"${SITES_ROOT_PATH_DOMAINS[*]}\""
    exit 2
fi

write_success "silverstripebackup-cron" "done"