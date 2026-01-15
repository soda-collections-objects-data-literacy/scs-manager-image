# SCS Manager Docker Image

A production-ready Docker image for the SODa SCS (Soda Collections) Manager built on Drupal 11 with NGINX, PHP-FPM, and PHP 8.3.

## Overview

This Docker image provides a pre-configured Drupal 11 installation with the SODa SCS Manager module and all necessary dependencies. The image includes automated site installation, configuration synchronization, and content import on first startup.

**Base Image:** `drupal:11.3.2-php8.3-fpm-bookworm`

**SCS Manager Version:** main branch

## Features

- **Drupal 11.3.2** with PHP 8.3, NGINX, and PHP-FPM on Debian Bookworm
- **Pre-installed modules:**
  - SODa SCS Manager (custom module)
  - Admin Toolbar, Devel, Gin admin theme
  - Book, Book Tree Menu, Custom Book Block
  - Content Entity Sync, Single Content Sync
  - OpenID Connect, SMTP
  - CKEditor Font, Linkit, Token, Pathauto
  - Language Icons, SVG Image, IMCE
  - Redis module for caching
  - Health Check module
  - And more (see Dockerfile for complete list)
- **PHP Extensions:**
  - GD with AVIF, WebP, JPEG, and PNG support
  - APCu for opcode caching
  - Redis for session and cache storage
  - Upload Progress for better file upload UX
  - GMP for arbitrary precision arithmetic
  - Intl for internationalization
  - Xdebug (development mode only)
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

**Note:** Redis is optional but recommended for session storage. If Redis is not available, PHP will fall back to file-based sessions.

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
3. Enable all required modules
4. Configure the Gin admin theme
5. Add German language support
6. Import configuration from `/opt/drupal/sync/configs`
7. Import default content for the SCS Manager module
8. Set proper file permissions

This process may take 2-5 minutes. Subsequent startups are instant.

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

The image includes Redis support for session storage:

- **PHP Extension:** Redis PECL extension installed and enabled
- **Session Handler:** Configured to use Redis (database 2)
- **Drupal Module:** Redis module (`drupal/redis:^1.11`) included
- **Connection:** `tcp://redis:6379?database=2`

To use Redis, ensure a Redis container is available at hostname `redis` on port `6379`. The Redis settings file is automatically included if present at `/opt/drupal/web/sites/default/settings.redis.php`.

## Development Mode

To get the image with development options use the `ghcr.io/soda-collections-objects-data-literacy/scs-manager-image-development:latest` image.

Xdebug configuration:
- Mode: `debug,develop`
- Client host: `host.docker.internal`
- Port: `9003`
- IDE key: `scs`
- Trigger value: `scs`

Configure your IDE to listen on port 9003 and use the IDE key `scs`.

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

Reset permissions inside the container:

```bash
docker exec -it scs-manager chown -R www-data:www-data /opt/drupal
docker exec -it scs-manager chmod -R 775 /opt/drupal
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

**APCu cache:**
- Shared memory size: 32M
- Enabled for CLI (development)

**OPcache:**
- Memory consumption: 128M
- Max accelerated files: 4000
- Revalidation frequency: 0 (development mode) or default (production)

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
