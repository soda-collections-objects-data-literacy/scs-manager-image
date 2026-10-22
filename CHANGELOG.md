# Changelog

## 3.2.0

### Added
- Development image tooling: `drupal/core-dev` at the installed core version (PHPUnit, PHPStan with phpstan-drupal and phpstan-phpunit, PHP_CodeSniffer with Coder, Mink, Prophecy), `phpstan/phpstan-deprecation-rules`, `php-parallel-lint/php-parallel-lint`, Kint, Node.js 24 with CSpell, and CLI helpers (`rg`, `fd`, `jq`, `tree`, `less`, `ssh`, …).
- `scs-lint` (development): runs lint, PHPCS/PHPCBF, PHPStan, CSpell and PHPUnit against the module or a given extension; falls back to Drupal GitLab CI-style defaults when the extension has no config of its own.
- `developer` user (development) in the `www-data` group; `DEV_UID` / `DEV_GID` move it to the host IDs on start. The codebase is group-writable for it.
- Development installs `soda_scs_manager` from source (git checkout) and clones the theme with full history. Pushes go over SSH (`pushInsteadOf`), fetches stay on HTTPS.
- `tini` as PID 1 and an image `HEALTHCHECK` on `/health`.
- Per-mode PHP configs under `configs/php/` (`production/`, `development/`).
- Contrib modules the SCS deployments use: `ckeditor5_plugin_pack`, `colorbox`, `eu_cookie_compliance`, `image_effects`, `imagemagick`, `nextcloud_webdav_mount`, `paragraphs`, `simple_menu_permissions`, `token_filter`.
- JS libraries for colorbox: Colorbox 1.7.0 and DOMPurify 3.4.0 under `web/libraries` (`COLORBOX_LIBRARY_VERSION`, `DOMPURIFY_VERSION`).
- Database updates on image upgrades: the image records a fingerprint of its `composer.lock`; when an installed site was last updated with another one, the entrypoint runs `drush updatedb` and `drush cr` before anything else touches the site.

### Changed
- The development image checks out `soda_scs_manager` on the `3.x` branch (`SODA_SCS_MANAGER_DEV_VERSION=3.x-dev`) instead of the release tag, so module work starts on the development branch. Production keeps the release (`SODA_SCS_MANAGER_VERSION=^3.1`).
- `SODA_SCS_MANAGER_VERSION` defaults to `^3.1`: soda_scs_manager 3.0.0 cannot be installed on a fresh Drupal 11.4 site (theme listed as a module dependency, missing `field.storage.node.body`).
- Multi-stage build: PHP extensions compile in a builder stage, the runtime image keeps no `-dev` headers.
- phpredis builds from its GitHub release tag (`PHPREDIS_VERSION`, default `6.3.0`): pecl.php.net answered 504 for `redis-6.3.0.tgz`. APCu and Xdebug stay on PECL, one package per call with retries.
- Production OPcache does not re-stat files and uses the tracing JIT; development re-stats on every request with the JIT off.
- APCu: 256M, off for the CLI.
- Xdebug (development) uses trigger mode and `127.0.0.1` (IDE attached into the container) instead of starting with every request. The file name stays `zz-xdebug-custom.ini`, so existing bind mounts still replace it.
- First install enables devel only in the development image. devel stays in the production codebase for sites that enabled it earlier.
- First install no longer chowns the whole codebase to `www-data` with mode 775: the codebase stays root-owned, the sites volume belongs to `www-data`, `settings.php` is 444.
- `drupal/coder` and `kint-php/kint` moved out of the production image.
- Entrypoint Drush runs with `XDEBUG_MODE=off`.
- The GitHub workflow builds the `3.x` branch, tags images with the branch name, and moves `latest` only with the newest release tag.

### Fixed
- Redis cache: settings.php included a `settings.redis.php` that never existed, so Drupal never used Redis. The Redis settings now live at `/var/configs/redis.settings.php` (outside the sites volume, without a connect probe on every bootstrap); the entrypoint adds the include and enables the `redis` module on every start where they are missing, also for existing sites.
- `/var/scs-manager` (private files) exists and belongs to `www-data`.

## 3.1.0

### Changed
- Base image → `drupal:11.4-php8.5-fpm-bookworm` (PHP 8.5). Build with `--pull` so the image picks up PHP 8.5.12+, which fixes CVE-2026-109618 and CVE-2026-109619.

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
