# Changelog

## 3.0.0

### Changed
- Base image → `drupal:11.4-php8.4-fpm-bookworm` (Drupal 11.4 / PHP 8.4); Composer core pins `^11.4`.
- Install [SODa SCS Manager](https://www.drupal.org/project/soda_scs_manager) via Composer (`drupal/soda_scs_manager:^3.0`) instead of cloning the former GitHub `main` branch into `modules/custom`.
- First-run content sync path updated to `modules/contrib/soda_scs_manager/content/sync`.
- Enable and set `soda_scs_manager_theme` as the default theme on first install (required module dependency).

### Added
- Build args `SODA_SCS_MANAGER_VERSION` (default `^3.0`) and `SODA_SCS_MANAGER_THEME_REF` (default `1.x`).
- Clone companion theme from `https://github.com/rnsrk/soda_scs_manager_theme.git` (not yet on Drupal.org).

## 2.0.0

### Breaking Changes
- Replaced Apache2 with NGINX + PHP-FPM architecture.
- Container now exposes port 80 directly (no separate nginx-proxy container needed).
- PHP-FPM uses Unix socket (`/run/php/php-fpm.sock`) instead of TCP for better performance.

### Added
- Integrated NGINX web server into the image.
- NGINX configuration files baked into the image (`nginx.conf` and `drupal.conf`).
- Redis PHP extension (PECL redis).
- Redis session handling configuration.
- Redis Drupal module (`drupal/redis:^1.11`).
- Redis settings file (`redis.settings.php`).
- Health Check Drupal module (`drupal/health_check:^3.1`) for `/health` endpoint.
- `curl` utility for health checks and debugging.
- `libicu-dev` system dependency for intl PHP extension.
- NGINX log symlinks to stdout/stderr for Docker logging.

### Changed
- Entrypoint now starts PHP-FPM in background and uses `exec` to run NGINX as PID 1.
- NGINX uses CMD pattern for proper signal handling.
- NGINX access logging disabled in production mode (errors only).
- Simplified deployment architecture (single container instead of multi-container setup).

### Removed
- Apache2 web server.
- Dependency on external nginx-proxy container.

## 1.0.0
- First stable version.
