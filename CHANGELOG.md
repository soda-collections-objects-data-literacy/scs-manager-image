# Changelog

## [Unreleased]

## 3.10.1 - 2026-11-27

### Changed

- Ships SODa SCS Manager module 4.8.3: application detail pages show the SQL
  and triplestore access data to the owner again, and the create-project wizard
  is easier to use with the keyboard and screen readers.
- Theme: the funding and home page content now carries the logo link fields.
  No action needed; the image bakes the theme content, so rebuilding is enough.

## 3.10.0 - 2026-11-27

### Added

- Theme: a styled 404 page for the manager (`page--404.html.twig`).
- Theme: progress bar styling for the delete-project batch, a throbber overlay
  and accessibility improvements in the create-project wizard.

### Changed

- Theme: the manager CSS is rebuilt from the SCSS (administration styles
  consolidated, design comments added). Production keeps installing
  `drupal/soda_scs_manager` at `^4.3` and picks up 4.8.2.
  **Pull and recreate the manager container.**

## 3.9.2 - 2026-11-25

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.8.2
  (SCS Manager admins see the Delete and Reset demo controls on every project;
  members who may not delete a project no longer see its Delete entry).

## 3.9.1 - 2026-11-23

### Fixed

- Theme migrates legacy funding and partner logos into the paired fields and
  sets `field_logos_migrated` without the helper module `scs_theme_content`,
  so sites that already ran `logo_pairs` (Prime after 3.9.0) can finish
  `remove_legacy_logo_fields`. Production still installs
  `drupal/soda_scs_manager` at `^4.3` and picks up 4.8.1 (sliders icon on the
  SCS Manager administration menu link).
  **Pull and recreate the manager container; the entrypoint runs
  `drush updatedb` and completes the logo-field cleanup.**

## 3.9.0 - 2026-11-23

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.8.0
  (demo source owned by the protected service account `scs_demo`, own URIs
  for demo WissKIs, export and import of demo versions, project ownership
  transfer). The module needs Drupal 11.2; the image ships 11.4.
  **Set `SCS_DEMO_ACCOUNT_PASSWORD` in the deployment `.env`, recreate the
  manager container and run `drush soda_scs_manager:demo-account`, then choose
  the demo project again on the demo page.**

## 3.8.3 - 2026-11-23

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.7.2
  (demo WissKIs no longer show a second SSO button after a restore).

## 3.8.2 - 2026-11-19

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.7.1
  (unit tests for demo template build guards and triplestore owner-token sync).

## 3.8.1 - 2026-11-19

### Fixed

- Apply a composer patch for `drupal/field_group` so horizontal tabs initialize
  on Drupal >= 10.4 / 11.1 (`weight: -1` no longer loads the JS before jQuery;
  [field_group#3625536](https://www.drupal.org/project/field_group/issues/3625536)).
  Drop the patch once upstream ships the fix.

## 3.8.0 - 2026-11-18

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.7.0
  (orphan resources admin page, team member role controls, confirmation overlays,
  demo template and triplestore token fixes, session-expiry polling stop). Theme
  styles the member editor and overlays; shipped menu links for administration
  and docs are refreshed. **Update theme and module together.** **Build a new
  demo template version from an installed source WissKI that has the
  `api-import` account and the role `wisski_api_import`, then activate it, and
  reset existing demo projects.**

## 3.7.0 - 2026-11-17

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.6.0
  (WebProtégé "Import ontology" tab; first revision on create so ontology
  download and demo template export work). **After updating, run
  `drush soda_scs_manager:backfill-webprotege-projects --all` once.**

## 3.6.0 - 2026-11-17

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.5.0
  (Snapshots card on stack/component detail, admin conversations, demo status
  panel, service-key owner access, Administer SODa SCS Manager on all entity
  types, project/account delete batches, OpenGDB grant and token fixes, no
  module CSS — styles live in `scs_custom_theme`). Theme brings the manager UI
  styles, conversation theming, and a funding-and-partners section on the home
  page (shipped content export). **Run `drush updb`** on existing sites
  (updates 11041–11042). **Update theme and module together.**

## 3.5.0 - 2026-11-12

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.4.0
  (optional WissKI Default Data Model on create, clearer create failures,
  WissKI container wait, OpenGDB nullable fix, unknown entity URLs as 404,
  WSOD without exception message). Theme `scs_custom_theme` drops the
  exception message from the WSOD template.

## 3.4.3 - 2026-11-11

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.3.3
  (empty `machineName` is derived while the form reads the POST, so the Create
  Project wizard works under JS aggregation with the field still required).

## 3.4.2 - 2026-11-11

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.3.2
  (Create Project wizard derives `machineName` on the server when JS
  aggregation clears the client field).

## 3.4.1 - 2026-11-10

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` and picks up 4.3.1
  (German translation file valid again; Gin status field PHP 8.5 fix on
  non-node Views such as People).

## 3.4.0 - 2026-11-10

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.3` (`SODA_SCS_MANAGER_VERSION`, also in the image workflow). 4.3.0 is the first release that ships its own CSS. Its update 11039 removes the retired `soda_scs_manager_theme` from an existing site on the next start.

### Removed

- The `soda_scs_manager_theme` clone and the build argument `SODA_SCS_MANAGER_THEME_REF`. A fresh install enables only `scs_custom_theme` and Gin. **Drop a `scs-manager-theme` volume or bind mount** from development compose files.

## 3.3.4 - 2026-11-09

### Fixed

- The shipped content import failed with "The imported file extension is not allowed" because the pages reference SVG logos. The entrypoint now adds `svg` to the allowed file extensions of Single Content Sync before the import.

## 3.3.3 - 2026-11-09

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.1` (`SODA_SCS_MANAGER_VERSION`, also in the image workflow). 4.1.0 adds the WissKI "Admin tasks" panel and the "Update" button for SCS administrators and drops the "WissKI 8.x-4.x Development" option. The entrypoint runs its database update 11037 on start.

## 3.3.2 - 2026-11-09

### Fixed

- Install `librsvg2-bin` so ImageMagick can read SVG files (`rsvg-convert` delegate). Without it `identify` failed on SVG logos, e.g. during `drush updb`.

### Changed

- The rolling development line is `main` (image tag `:main`); the `3.x` branch is retired. Stable releases stay plain version tags. A `X.x` branch is only cut from a release tag to maintain an older major.

## 3.3.1 - 2026-11-07

### Added

- The image installs `antibot` (`drupal/antibot:^2.0`) and enables `antibot`, `simple_menu_permissions`, and `token_filter`. `simple_menu_permissions` and `token_filter` were already Composer packages but never enabled. An already installed site gets the three enabled on start when they were missing.
- Production and development images include `scs_custom_theme` (`SCS_CUSTOM_THEME_REF`, default `main`) from `https://github.com/soda-collections-objects-data-literacy/scs_custom_theme`. The build clones it over HTTPS. Production drops `.git`; development keeps a full clone. First install sets it as the default theme. Gin stays the admin theme. An already installed site gets the theme enabled on start when it was missing.

### Changed

- Production installs `drupal/soda_scs_manager` at `^4.0` (`SODA_SCS_MANAGER_VERSION`): the 4.0 release line, without a patch pin. The development image checks out the `4.x` branch (`SODA_SCS_MANAGER_DEV_VERSION=4.x-dev`). The image workflow passes both as build args from its env.
- Contrib floors follow the current compatible releases: Linkit `^7.0.17`, OpenID Connect `^3.0.0-alpha9@alpha`, SVG Image `^3.2.5`, Token `^1.18`. Later patch releases on the same line still install. `core-recipe-unpack` is required explicitly so it moves with the other core metapackages.
- The entrypoint imports the home page and legal pages from `scs_custom_theme/content/sync` when that tree differs from the last import (`web/sites/.scs-content-version`). The same import runs on first install. A failed import is retried on the next start.

### Removed

- `drupal/bootstrap5`. The theme is not enabled.

### Fixed

- The image build updates `drupal/core` together with the core metapackages (`composer require --with-all-dependencies`, and `drupal/core` listed explicitly). 3.3.0 failed here: the base image lock kept core at 11.4.11, so core-recommended 11.4.12 could not be installed. No 3.3.0 image was published.

### Security

- Drupal core metapackages are required at `^11.4.12` (security release 11.4.10, recommended 11.4.12). `drupal/externalauth` is a direct requirement at `^2.0.15` (security release 2.0.13). `drupal/single_content_sync` is `^1.4.19`. Gin is `^5.0.16`. A build can no longer resolve the vulnerable releases.

## 3.3.0 - 2026-11-07 [YANKED]

The tag exists. The image build failed before publishing, for the reason fixed in 3.3.1. No image was published.

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
