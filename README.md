# SSPak Docker

A Docker container image for capturing or restoring backups of Silverstripe installations using SSPAK.

[Read more about this repository here.](https://lucshelton.com/blog/backing-up-silverstripe-in-docker)

## Run

```bash
#!/bin/bash
docker run --rm -i portfolio/sspak-docker:development /bin/bash
```

## Purpose

Conveniently capture and restore backups of a [SilverStripe](https://silverstripe.org/) installation that are timestamped and kept organized at a path mounted inside of a container. This Docker image utilizes `sspak`, a command-line tool developed by the [SilverStripe](https://silverstripe.org/) team that can capture the contents of the database, and website's upload `/public/assets/Uploads` directory, so that it can be conveniently restored.

- Keeps a maximum of 5 backups.
- Timestamps each backup.
- Updates the `latest.tgz` archive with the latest on each backup.
- Enables for remote restoration and capturing of backups if `docker --context` is configured.

## Guide

A few explanations on how to use this.

### Configuration

- `BACKUPS_PATH`
  - The root path within the container for capturing backups

### Restoring Backups

Backups can be restored manually to either a remote or the default/local Docker context.

```shell
#!/bin/bash
sspak-docker.sh -o restore
```

```bash
#!/bin/bash
sspak-docker.sh -o restore
```

### Capturing Backups

Backups can be manually captured when there is a running instance of SilverStripe, and the supporting SQL database server.

```bash
sspak-docker.sh -o backup
```

### Scheduled Backups

This Docker image supports the ability to schedule backups using CRON jobs that are configured inside the container. The container makes use of Alpine Linux.

## Special Thanks

[Thanks to this particular GitHub repository for the inspiration.](https://github.com/databacker/mysql-backup)

## Links

Find below some relevant links.

- **SSPak**
  - The official repository for the tool that this Docker image uses.
  - [GitHub Repository](https://github.com/silverstripe/sspak)
- **Blog**
  - An article explaining what this Docker image does, and how to use it.
  - [Docker SilverStripe Backup](https://lucshelton.com/projects/personal/silverstripe-tool-docker-backup/)
