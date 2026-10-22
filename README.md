# SCS Manager Docker Image

A production-ready Docker image for the SODa SCS (Soda Collections) Manager built on Drupal 11.4 with NGINX, PHP-FPM, and PHP 8.5.

## Overview

This Docker image provides a pre-configured Drupal 11 installation with the SODa SCS Manager module and all necessary dependencies. The image includes automated site installation, configuration synchronization, and content import on first startup.

**Base Image:** `drupal:11.4-php8.5-fpm-bookworm`

**SCS Manager:** [`drupal/soda_scs_manager:^3.1`](https://www.drupal.org/project/soda_scs_manager) via Composer (Drupal.org)

## Images

One Dockerfile builds two images; the `MODE` build argument selects which.

| Image | `MODE` | For |
|-------|--------|-----|
| `ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-production` | `production` | Running SCS Manager. No Xdebug, no dev Composer packages, OPcache without file re-stat, devel not enabled, NGINX logs only errors. |
| `ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development` | `development` | Working on SCS Manager and its theme. Xdebug, PHPUnit, PHPStan, PHP_CodeSniffer, CSpell, Node.js, a `developer` user, and the module and theme as git checkouts. See [Development Image](#development-image). |

Tags: `latest` (newest release), `<major>`, `<major>.<minor>`, `<version>`, the branch name (`3.x`) and `sha-<commit>`.

## Features

- **Drupal 11.4** with PHP 8.5, NGINX, and PHP-FPM on Debian Bookworm
- **Pre-installed modules:**
  - [SODa SCS Manager](https://www.drupal.org/project/soda_scs_manager) (`drupal/soda_scs_manager:^3.1` from packages.drupal.org)
  - Companion theme `soda_scs_manager_theme` (Git clone until published on Drupal.org)
  - Admin Toolbar, Gin admin theme, Devel (enabled in the development image only)
  - Book, Book Tree Menu, Custom Book Block
  - Content Entity Sync, Single Content Sync
  - OpenID Connect, SMTP, Field Group (module hard dependencies)
  - CKEditor Font, Linkit, Token, Pathauto
  - Language Icons, SVG Image, IMCE
  - Redis module for caching
  - Health Check module
  - CKEditor 5 Plugin Pack, Colorbox, EU Cookie Compliance, ImageMagick, Image Effects, Paragraphs, Simple Menu Permissions, Token Filter, Nextcloud WebDAV Mount
  - And more (see Dockerfile for complete list)
- **PHP Extensions:**
  - GD with AVIF, WebP, JPEG, and PNG support
  - APCu for opcode caching
  - Redis for session and cache storage
  - Upload Progress for better file upload UX
  - GMP for arbitrary precision arithmetic
  - Intl for internationalization
  - Xdebug (development image only)
- **Web Server:** NGINX with optimized configuration
- **Session Storage:** Redis (database 2)
- **Optimized PHP settings** for large file uploads and content management
- **Automated setup:** First-run installation and configuration import
- **Multi-language support:** German language pre-configured
- **Health check endpoint** (`/health`) for monitoring and orchestration

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 2.0 or later (optional, but recommended)
- MariaDB 11.5+ or MySQL 8.0+ database server
- [SCS Manager Deployment infrastructure](https://github.com/soda-collections-objects-data-literacy/soda_scs_manager_deployment) with traefik, mariadb, portainer, keycloak, opengdb, nextcloud (with openoffice), jupyterhub (with openrefine) and webprotégé.

## Quick Start (for dummy evaluation)

### Using Docker Compose (Recommended)

Create a `docker-compose.yml` file:

```yaml
services:
  scs-manager:
    image: ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-production:latest
    container_name: scs-manager
    volumes:
      - scs-manager-sites:/opt/drupal/web/sites
    environment:
      DB_DRIVER: mysql
      DB_HOST: database
      DB_NAME: drupal
      DB_PASSWORD: your_secure_database_password
      DB_PORT: 3306
      DB_USER: drupal
      DRUPAL_USER: admin
      DRUPAL_PASSWORD: your_secure_admin_password
      DRUPAL_SITE_NAME: "SCS Manager"
    ports:
      - "8080:80"
    depends_on:
      - database
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 120s

  database:
    image: mariadb:11.5.2
    container_name: scs-database
    environment:
      MYSQL_ROOT_PASSWORD: your_secure_root_password
      MYSQL_DATABASE: drupal
      MYSQL_USER: drupal
      MYSQL_PASSWORD: your_secure_database_password
    volumes:
      - scs-database-data:/var/lib/mysql

  redis:
    image: redis:8-alpine
    container_name: scs-redis
    restart: always
    command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - scs-redis-data:/data

volumes:
  scs-manager-sites:
  scs-database-data:
  scs-redis-data:
```

**Note:** Redis is required: it stores the PHP sessions and the Drupal cache.

Start the services:

```bash
docker-compose up -d
```

Access the site at `http://localhost:8080`

### Using Docker CLI

Create a network and start the database:

```bash
docker network create scs-network

docker run -d \
  --name scs-database \
  --network scs-network \
  -e MYSQL_ROOT_PASSWORD=your_secure_root_password \
  -e MYSQL_DATABASE=drupal \
  -e MYSQL_USER=drupal \
  -e MYSQL_PASSWORD=your_secure_database_password \
  -v scs-database-data:/var/lib/mysql \
  mariadb:11.5.2
```

Start the SCS Manager container:

```bash
docker run -d \
  --name scs-manager \
  --network scs-network \
  -p 8080:80 \
  -e DB_DRIVER=mysql \
  -e DB_HOST=scs-database \
  -e DB_NAME=drupal \
  -e DB_PASSWORD=your_secure_database_password \
  -e DB_PORT=3306 \
  -e DB_USER=drupal \
  -e DRUPAL_USER=admin \
  -e DRUPAL_PASSWORD=your_secure_admin_password \
  -e DRUPAL_SITE_NAME="SCS Manager" \
  -v scs-manager-sites:/opt/drupal/web/sites \
  ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-production:latest
```

## Environment Variables

### Required Variables for SCS Manager Container

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_DRIVER` | Database driver | `mysql` |
| `DB_HOST` | Database hostname | `database` or `mariadb` |
| `DB_NAME` | Database name | `drupal` |
| `DB_PASSWORD` | Database password | `your_secure_password` |
| `DB_PORT` | Database port | `3306` |
| `DB_USER` | Database username | `drupal` |
| `DRUPAL_USER` | Drupal admin username | `admin` |
| `DRUPAL_PASSWORD` | Drupal admin password | `your_secure_password` |
| `DRUPAL_SITE_NAME` | Site display name | `SCS Manager` |

### Required Variables for Database Container

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_ROOT_PASSWORD` | MariaDB/MySQL root password | `your_secure_root_password` |
| `MYSQL_DATABASE` | Database name (same as `DB_NAME`) | `drupal` |
| `MYSQL_USER` | Database user (same as `DB_USER`) | `drupal` |
| `MYSQL_PASSWORD` | Database password (same as `DB_PASSWORD`) | `your_secure_password` |

### Using Environment File

Create a `.env` file (see `example-env` for reference):

```env
# Database configuration
DB_DRIVER=mysql
DB_HOST=database
DB_NAME=drupal
DB_PASSWORD=your_secure_database_password
DB_PORT=3306
DB_ROOT_PASSWORD=your_secure_root_password
DB_USER=drupal


# Drupal site configuration
DRUPAL_SITE_NAME=SCS Manager
DRUPAL_USER=admin
DRUPAL_PASSWORD=your_secure_admin_password
```

Reference it in docker-compose.yml:

```yaml
services:
  scs-manager:
    env_file: .env
```

## Volumes

The image uses the following important directories:

| Path | Purpose | Recommended Volume |
|------|---------|-------------------|
| `/opt/drupal/web/sites` | Drupal sites directory (settings, files) | Yes |
| `/opt/drupal/sync/configs` | Configuration sync directory | Optional |

Example volume mounting:

```yaml
volumes:
  - scs-manager-sites:/opt/drupal/web/sites
  - ./custom-configs:/opt/drupal/sync/configs
```

## First Run Behavior

On the first startup, the entrypoint script will:

1. Wait for the database to be ready
2. Install Drupal with the provided credentials
3. Enable all required modules (devel only in the development image)
4. Configure the Gin admin theme
5. Add German language support
6. Import configuration from `/opt/drupal/sync/configs`
7. Import default content for the SCS Manager module
8. Set file permissions: the sites volume belongs to `www-data`, `settings.php` is read-only

This process may take 2-5 minutes. Subsequent startups are instant.

On later starts of an installed site, the entrypoint runs `drush updatedb` and `drush cr` once whenever the image ships a different package set (fingerprint of its `composer.lock`, compared with `web/sites/.scs-packages-version`). A failed update is retried on the next start.

## Running Drush Commands

To execute Drush commands inside the running container:

```bash
docker exec -it scs-manager drush cr
docker exec -it scs-manager drush config:export
docker exec -it scs-manager drush user:login
```

## Running Composer Commands

To run Composer commands:

```bash
docker exec -it scs-manager composer require drupal/module_name
docker exec -it scs-manager composer update
```

## Redis Configuration

Redis holds the PHP sessions and the Drupal cache, so the container needs a Redis server at hostname `redis` (`REDIS_HOST` / `REDIS_PORT` change it for the cache; sessions always use `redis:6379`).

- **PHP Extension:** phpredis, built from its GitHub release
- **Sessions:** `tcp://redis:6379?database=2`, with locking
- **Drupal cache:** Redis module (`drupal/redis:^1.11`); all bins except `form`, plus the bootstrap container, lock, flood and queue backends
- **Settings:** `/var/configs/redis.settings.php` in the image. On every start the entrypoint makes sure `settings.php` includes it and the `redis` module is enabled, so sites installed by older images switch to the Redis cache as well.

## Development Image

`ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development` is the production image plus:

| Tool | Where |
|------|-------|
| Xdebug 3.5 (`debug,develop`, trigger mode) | PHP extension, `/usr/local/etc/php/conf.d/zz-xdebug-custom.ini` |
| PHPUnit, Mink, Prophecy (`drupal/core-dev` at the installed core version) | `/opt/drupal/vendor/bin/phpunit` |
| PHPStan with phpstan-drupal, phpstan-phpunit and deprecation rules | `/opt/drupal/vendor/bin/phpstan` |
| PHP_CodeSniffer with the Drupal and DrupalPractice standards (Coder) | `/opt/drupal/vendor/bin/phpcs`, `phpcbf` |
| PHP Parallel Lint | `/opt/drupal/vendor/bin/parallel-lint` |
| CSpell, Node.js 24, npm | global (`cspell`, `node`, `npm`) |
| devel (enabled on the first start) and Kint | Drupal modules / Composer |
| CLI helpers: `rg`, `fd`, `jq`, `tree`, `less`, `ssh`, `file`, `gpg` | `/usr/bin` |
| `scs-lint` | `/usr/local/bin/scs-lint` |

The lint and test tools sit in the site's `vendor/`, the same layout as the Drupal GitLab CI, so PHPStan and PHPUnit load the real Drupal codebase. `vendor/bin` is on `PATH`, for login shells as well.

### Module and theme as git checkouts

`soda_scs_manager` (`web/modules/contrib/soda_scs_manager`) is installed from source as `3.x-dev` (`SODA_SCS_MANAGER_DEV_VERSION`): a git clone of `https://git.drupalcode.org/project/soda_scs_manager.git` with the `3.x` branch checked out and tracking `origin/3.x`. The production image takes the release instead (`SODA_SCS_MANAGER_VERSION`). The theme (`web/themes/custom/soda_scs_manager_theme`) is a full clone of `SODA_SCS_MANAGER_THEME_REF`. Fetches use HTTPS without keys; `git push` goes over SSH (`git@git.drupal.org:`, `git@github.com:`), so mount your SSH key to push.

Put a named volume on each path so branches and uncommitted work survive container recreation and image pulls. Docker seeds an empty named volume from the image once; later image updates do not touch it, so update the clones with git. Or bind-mount an existing clone from the host instead.

### The `developer` user

nginx and PHP-FPM run as root and `www-data` as usual. The image also has a `developer` user (in the `www-data` group, no sudo) for an IDE, an agent, or `docker exec -u developer`. The codebase under `/opt/drupal` is group-writable for `www-data`, so `developer` can edit, run Composer and use git there.

Set `DEV_UID` / `DEV_GID` to your host user's IDs (`id -u`, `id -g`); the entrypoint moves `developer` to them on every start, so bind-mounted clones and `~/.ssh` stay writable without copying.

### Docker Compose example

```yaml
services:
  scs-manager:
    image: ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development:latest
    environment:
      # ...the variables from Quick Start, plus:
      DEV_UID: 1000
      DEV_GID: 1000
      # Xdebug runs in trigger mode; XDEBUG_MODE=off switches it off.
      XDEBUG_MODE: debug,develop
      # For an IDE on the host instead of attached into the container:
      # XDEBUG_CONFIG: client_host=host.docker.internal
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - scs-manager-sites:/opt/drupal/web/sites
      - scs-manager-module:/opt/drupal/web/modules/contrib/soda_scs_manager
      - scs-manager-theme:/opt/drupal/web/themes/custom/soda_scs_manager_theme
      # Push over SSH as developer (keys must belong to DEV_UID):
      # - ~/.ssh:/home/developer/.ssh:ro
      # Keep the IDE server between recreations:
      # - scs-manager-vscode-server:/home/developer/.vscode-server
    labels:
      # Attach Cursor / VS Code as `developer` (not root). PID 1 stays root.
      devcontainer.metadata: '[{"remoteUser":"developer","workspaceFolder":"/opt/drupal/web/modules/contrib/soda_scs_manager"}]'

volumes:
  scs-manager-sites:
  scs-manager-module:
  scs-manager-theme:
```

Do not bind-mount the whole `/opt/drupal` from the host: that hides the baked `vendor/` with PHPUnit, PHPStan and PHP_CodeSniffer.

### Xdebug

- Mode: `debug,develop`, `start_with_request=trigger`
- Client host: `127.0.0.1` (IDE attached into the container); for an IDE on the host set `XDEBUG_CONFIG=client_host=host.docker.internal`
- Port: `9003`
- IDE key: `scs`
- Log: `/var/log/xdebug/xdebug.log`

Start a session with the `XDEBUG_TRIGGER` / `XDEBUG_SESSION` cookie or query parameter (a browser helper sets it). For Drush: `XDEBUG_TRIGGER=1 drush …`. The entrypoint runs its own Drush calls with `XDEBUG_MODE=off`.

To replace the Xdebug settings completely, bind-mount your own file onto `/usr/local/etc/php/conf.d/zz-xdebug-custom.ini`.

### Lint and test

`scs-lint` runs the tools against the SODa SCS Manager module, or the extension path you pass. An extension's own `phpcs.xml(.dist)`, `phpstan.neon(.dist)`, CSpell config and `phpunit.xml(.dist)` win; otherwise the fallbacks in `/usr/local/share/scs-dev/` apply (Drupal and DrupalPractice standards, PHPStan level 0, the Drupal core CSpell dictionaries, core's `phpunit.xml.dist`).

```bash
docker exec -it -u developer scs-manager scs-lint                 # lint, phpcs, phpstan, cspell
docker exec -it -u developer scs-manager scs-lint phpstan
docker exec -it -u developer scs-manager scs-lint phpcbf           # fix what PHPCS can
docker exec -it -u developer scs-manager scs-lint cspell web/themes/custom/soda_scs_manager_theme
docker exec -it -u developer scs-manager scs-lint phpunit -- --testsuite kernel
```

Arguments after `--` go to the tool. `scs-lint phpunit` uses `SIMPLETEST_DB` when set; otherwise it builds it from `DB_*`, so kernel and functional tests create prefixed tables in the site database. Run tests as `developer`: browser output goes to `web/sites/simpletest/browser_output`, which the entrypoint prepares.

The tools also work directly, for example `phpcs --standard=Drupal,DrupalPractice web/modules/contrib/soda_scs_manager` from `/opt/drupal`.

## Health Check

The image includes the Health Check module. Access the health check endpoint:

```bash
curl http://localhost:8080/health
```

The health check endpoint returns a 200 status when Drupal is fully initialized and ready to serve requests. This is used by Docker Compose health checks and orchestration tools to determine when the container is ready.

## Accessing the Site

- **Frontend:** `http://localhost:8080`
- **Admin Panel:** `http://localhost:8080/admin`
- **Login:** Use the credentials specified in `DRUPAL_USER` and `DRUPAL_PASSWORD`

## Building the Image

```bash
cd /path/to/scs-manager-image
docker build --pull --build-arg MODE=production -t scs-manager-image-production:local .
docker build --pull --build-arg MODE=development -t scs-manager-image-development:local .
```

Build arguments:

| Argument | Default | Purpose |
|----------|---------|---------|
| `MODE` | `production` | `production` or `development` |
| `DRUPAL_IMAGE` | `11.4-php8.5-fpm-bookworm` | Tag of the official `drupal` base image |
| `SODA_SCS_MANAGER_VERSION` | `^3.1` | Composer constraint for `drupal/soda_scs_manager` (production) |
| `SODA_SCS_MANAGER_DEV_VERSION` | `3.x-dev` | Branch of `drupal/soda_scs_manager` checked out in the development image |
| `SODA_SCS_MANAGER_THEME_REF` | `1.x` | Branch or tag of `soda_scs_manager_theme` |
| `PHPREDIS_VERSION` | `6.3.0` | phpredis release tag, built from GitHub |
| `COLORBOX_LIBRARY_VERSION` | `1.7.0` | Colorbox JS library for the colorbox module |
| `DOMPURIFY_VERSION` | `3.4.0` | DOMPurify (colorbox sanitizer), from npm |
| `NODE_MAJOR` | `24` | Node.js line (development) |
| `DEV_UID` / `DEV_GID` | `1000` | Build-time IDs of `developer` (development; the `DEV_UID` / `DEV_GID` environment variables change them at start) |

PHP extensions compile in a builder stage; the runtime image gets the extensions without the `-dev` headers. Pin a specific [SODa SCS Manager](https://www.drupal.org/project/soda_scs_manager) release or theme branch:

```bash
docker build \
  --build-arg MODE=production \
  --build-arg SODA_SCS_MANAGER_VERSION=3.0.0 \
  --build-arg SODA_SCS_MANAGER_THEME_REF=1.x \
  -t scs-manager-image-production:3.0.0 .
```

Default: `SODA_SCS_MANAGER_VERSION=^3.1` (Composer constraint from Drupal.org).

## Updating the Image

Pull the latest version:

```bash
docker pull ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-production:latest
docker-compose up -d
```

## Troubleshooting

### Container fails to start

Check the logs:

```bash
docker logs scs-manager
```

### Database connection issues

Ensure the database container is running and healthy:

```bash
docker ps
docker logs scs-database
```

### Permission issues

The codebase under `/opt/drupal` belongs to root (group-writable for `www-data` in the development image); PHP-FPM only writes to the sites volume and `/var/scs-manager`. Reset those:

```bash
docker exec -it scs-manager chown -R www-data:www-data /opt/drupal/web/sites /var/scs-manager
```

### Site already installed but needs reinstall

Remove the volume and restart.
CAUTION THIS DELETES EXISTING VOLUMES ALL DATA WILL BE LOST:

```bash
docker-compose down -v
docker-compose up -d
```

## PHP Configuration

The image includes optimized PHP settings:

- Memory limit: 1024M
- Upload max filesize: 1024M
- Post max size: 1024M
- Max execution time: 1200s
- Max input time: 600s
- Max file uploads: 50

**APCu cache** (`zz-apcu-custom.ini`):
- Shared memory size: 256M
- Off for the CLI, so cron and Drush do not keep stale caches

**OPcache** (`zz-opcache-recommended.ini`, per image):
- Production: no file re-stat (`validate_timestamps=0`), 512M, 30000 files, tracing JIT
- Development: re-stat on every request (`validate_timestamps=1`, `revalidate_freq=0`), 256M, JIT off (Xdebug)

**Session Configuration:**
- Handler: Redis (when Redis is available)
- Path: `tcp://redis:6379?database=2`
- Locking enabled with retry mechanism

## NGINX Configuration

The image includes NGINX with optimized settings:

- **Worker processes:** Auto (based on CPU cores)
- **Worker connections:** 1024
- **Gzip compression:** Enabled
- **Client max body size:** 1024M
- **Access logging:** Disabled in production mode
- **Error logging:** Configured to stderr for Docker logging

NGINX communicates with PHP-FPM via Unix socket (`/run/php/php-fpm.sock`) for optimal performance.

## License

See LICENSE.md for license information.

## Contributing

Contributions are welcome! Please refer to the project's GitHub repository for contribution guidelines.

## Support

For issues and questions, please open an issue on the GitHub repository:
https://github.com/soda-collections-objects-data-literacy/scs-manager-image
