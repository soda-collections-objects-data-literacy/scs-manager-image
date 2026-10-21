# Drupal 11.4 on PHP 8.5 FPM with NGINX and the SODa SCS Manager.
# MODE=production builds the lean runtime image (scs-manager-image-production),
# MODE=development adds Xdebug and the lint and test tools
# (scs-manager-image-development).
ARG DRUPAL_IMAGE=11.4-php8.5-fpm-bookworm

# -----------------------------------------------------------------------------
# Builder: compile PHP extensions; the -dev headers stay in this stage.
# -----------------------------------------------------------------------------
FROM drupal:${DRUPAL_IMAGE} AS builder

ARG MODE=production

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    git \
    libavif-dev \
    libfreetype6-dev \
    libgmp-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev; \
    rm -rf /var/lib/apt/lists/*

# GD again, this time with AVIF support (the Drupal image builds it without).
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif \
    && docker-php-ext-install -j"$(nproc)" gd

# GMP and intl.
RUN docker-php-ext-install -j"$(nproc)" gmp intl

# Upload progress.
RUN set -eux; \
    git clone https://github.com/php/pecl-php-uploadprogress/ /usr/src/php/ext/uploadprogress/; \
    docker-php-ext-configure uploadprogress; \
    docker-php-ext-install uploadprogress; \
    rm -rf /usr/src/php/ext/uploadprogress

# PECL extensions. pecl.php.net answers 504 now and then, and `pecl install`
# with several packages exits 0 when one download fails, so install one at a
# time and retry.
RUN set -eux; \
    { \
    echo '#!/bin/sh'; \
    echo 'for attempt in 1 2 3 4 5; do pecl install "$1" && exit 0; sleep $((attempt * 5)); done; exit 1'; \
    } > /usr/local/bin/pecl-install; \
    chmod +x /usr/local/bin/pecl-install

# APCu (enabled at runtime via configs/php/zz-apcu-custom.ini).
RUN pecl-install apcu

# Redis from its GitHub release tag: pecl.php.net times out on some release
# files (redis-6.3.0.tgz answered 504 for hours).
ARG PHPREDIS_VERSION=6.3.0
RUN set -eux; \
    mkdir -p /usr/src/php/ext/redis; \
    curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors \
    "https://github.com/phpredis/phpredis/archive/refs/tags/${PHPREDIS_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/src/php/ext/redis; \
    docker-php-ext-install -j"$(nproc)" redis; \
    rm -rf /usr/src/php/ext/redis

# Xdebug (development only).
RUN set -eux; \
    if [ "$MODE" = "development" ]; then \
    pecl-install xdebug-3.5.3; \
    docker-php-ext-enable xdebug; \
    fi

# -----------------------------------------------------------------------------
# Runtime: runtime libraries and the compiled extensions only.
# -----------------------------------------------------------------------------
FROM drupal:${DRUPAL_IMAGE}

ARG MODE=production
# The entrypoint reads MODE to tell the two images apart.
ENV MODE=${MODE} \
    COMPOSER_ALLOW_SUPERUSER=1

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-manager-image.git
LABEL org.opencontainers.image.description="Plain Drupal with preinstalled Site and SODa SCS Manager."

# Runtime packages only. Development also gets operator CLI helpers (rg, fd,
# jq, ssh, …) so docker exec, an attached IDE and agents find what they need.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    curl \
    default-mysql-client \
    git \
    imagemagick \
    libavif15 \
    libfreetype6 \
    libgmp10 \
    libicu72 \
    libjpeg62-turbo \
    libpng16-16 \
    libwebp7 \
    nginx \
    sendmail \
    tini \
    unzip \
    vim \
    wget; \
    if [ "$MODE" = "development" ]; then \
    apt-get install -y --no-install-recommends \
    bash-completion \
    fd-find \
    file \
    gnupg \
    jq \
    less \
    openssh-client \
    procps \
    ripgrep \
    tree; \
    ln -sfn /usr/bin/fdfind /usr/local/bin/fd; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# Node.js and CSpell (development only). Node also builds the theme CSS.
ARG NODE_MAJOR=24
RUN set -eux; \
    if [ "$MODE" != "development" ]; then \
    exit 0; \
    fi; \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    npm install -g cspell; \
    npm cache clean --force; \
    rm -rf /var/lib/apt/lists/*

# Compiled PHP extensions and their enablement snippets.
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/docker-php-ext-*.ini /usr/local/etc/php/conf.d/

# Who owns what:
# - /opt/drupal (core, vendor, modules, themes) belongs to root. PHP-FPM
#   (www-data) can read but not write it.
# - Development: the tree is group-writable with group www-data (setgid) so
#   `developer` (in www-data) can edit it. umask 002 covers git checkouts;
#   packages from zip archives keep their 644/755, so the RUNs that create
#   them end with `find … ! -perm -g=w -exec chmod g+w`.
# - The writable state (sites, private files) lives on volumes owned by
#   www-data.

# SODa SCS Manager release on Drupal.org (https://www.drupal.org/project/soda_scs_manager)
# and the companion theme, which is not on Drupal.org yet.
ARG SODA_SCS_MANAGER_VERSION=^3.1
ARG SODA_SCS_MANAGER_THEME_REF=1.x

# Drupal packages + SODa SCS Manager from packages.drupal.org. devel stays in
# the codebase for sites that enabled it before, but only development
# installs enable it. Development installs soda_scs_manager and the theme as
# git checkouts so they can be worked on in place.
RUN set -eux; \
    cd /opt/drupal; \
    if [ "$MODE" = "development" ]; then \
    umask 002; \
    composer config preferred-install.drupal/soda_scs_manager source; \
    fi; \
    composer require --no-interaction --no-progress \
    'drupal/admin_toolbar:^3.6' \
    'drupal/book:^2.0' \
    'drupal/book_tree_menu:^3.0' \
    'drupal/bootstrap5:^4.0' \
    'drupal/ckeditor5_plugin_pack:^1.5' \
    'drupal/ckeditor_font:^2.0@beta' \
    'drupal/colorbox:^2.2' \
    'drupal/content_entity_sync:^2.3' \
    'drupal/core-composer-scaffold:^11.4' \
    'drupal/core-project-message:^11.4' \
    'drupal/core-recommended:^11.4' \
    'drupal/custom_book_block:^2.0' \
    'drupal/devel:^5.3' \
    'drupal/entity_update:^3.0' \
    'drupal/eu_cookie_compliance:^1.29' \
    'drupal/field_group:^4.0' \
    'drupal/gin:^5.0' \
    'drupal/health_check:^3.1' \
    'drupal/image_effects:^5.0' \
    'drupal/imagemagick:^5.0' \
    'drupal/imce:^3.1' \
    'drupal/languageicons:^2.0@beta' \
    'drupal/linkit:^7.0' \
    'drupal/nextcloud_webdav_mount:^1.1' \
    'drupal/openid_connect:^3.0@alpha' \
    'drupal/paragraphs:^1.20' \
    'drupal/pathauto:^1.13' \
    'drupal/private_files_download_permission:^3.1' \
    'drupal/redis:^1.11' \
    'drupal/simple_menu_permissions:^3.0' \
    'drupal/single_content_sync:^1.4' \
    'drupal/smtp:^1.4' \
    "drupal/soda_scs_manager:${SODA_SCS_MANAGER_VERSION}" \
    'drupal/svg_image:^3.2' \
    'drupal/token:^1.17' \
    'drupal/token_filter:^2.2' \
    'drush/drush:^13.5'; \
    themeDir=web/themes/custom/soda_scs_manager_theme; \
    if [ "$MODE" = "development" ]; then \
    git clone --branch "${SODA_SCS_MANAGER_THEME_REF}" https://github.com/rnsrk/soda_scs_manager_theme.git "${themeDir}"; \
    else \
    git clone --depth 1 --branch "${SODA_SCS_MANAGER_THEME_REF}" https://github.com/rnsrk/soda_scs_manager_theme.git "${themeDir}"; \
    rm -rf "${themeDir}/.git"; \
    fi; \
    composer clear-cache; \
    ln -sf /opt/drupal/vendor/bin/drush /usr/local/bin/drush; \
    if [ "$MODE" = "development" ]; then \
    chgrp -R www-data /opt/drupal; \
    find /opt/drupal -xdev ! -type l ! -perm -g=w -not -path '*/node_modules/*' -exec chmod g+w {} +; \
    find /opt/drupal -xdev -type d -exec chmod g+s {} +; \
    fi

# JS libraries for the colorbox module (web/libraries/colorbox and
# web/libraries/dompurify). GitHub archive downloads fail now and then; retry.
ARG COLORBOX_LIBRARY_VERSION=1.7.0
ARG DOMPURIFY_VERSION=3.4.0
RUN set -eux; \
    if [ "$MODE" = "development" ]; then \
    umask 002; \
    fi; \
    curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors \
    "https://github.com/TurbojetTechnologies/colorbox/archive/${COLORBOX_LIBRARY_VERSION}.zip" -o /tmp/colorbox.zip; \
    unzip -qo /tmp/colorbox.zip -d /tmp; \
    mkdir -p /opt/drupal/web/libraries/colorbox /opt/drupal/web/libraries/dompurify; \
    cp -a --no-preserve=ownership "/tmp/colorbox-${COLORBOX_LIBRARY_VERSION}/." /opt/drupal/web/libraries/colorbox/; \
    curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors \
    "https://registry.npmjs.org/dompurify/-/dompurify-${DOMPURIFY_VERSION}.tgz" -o /tmp/dompurify.tgz; \
    tar -xzf /tmp/dompurify.tgz -C /tmp; \
    cp -a --no-preserve=ownership /tmp/package/dist /opt/drupal/web/libraries/dompurify/; \
    rm -rf /tmp/colorbox.zip "/tmp/colorbox-${COLORBOX_LIBRARY_VERSION}" /tmp/dompurify.tgz /tmp/package; \
    if [ "$MODE" = "development" ]; then \
    chgrp -R www-data /opt/drupal/web/libraries; \
    find /opt/drupal/web/libraries ! -perm -g=w -exec chmod g+w {} +; \
    fi

# Lint and test tools into the site vendor, the same layout as the Drupal
# GitLab CI: drupal/core-dev at the installed core version (PHPUnit, PHPStan
# with phpstan-drupal and phpstan-phpunit, PHP_CodeSniffer with Coder,
# Mink, Prophecy), PHPStan deprecation rules, PHP Parallel Lint, and Kint
# for devel. Development only.
RUN set -eux; \
    if [ "$MODE" != "development" ]; then \
    exit 0; \
    fi; \
    umask 002; \
    cd /opt/drupal; \
    coreVersion="$(composer show drupal/core --format=json | php -r 'echo json_decode(stream_get_contents(STDIN), true)["versions"][0] ?? "";')"; \
    test -n "${coreVersion}"; \
    composer require --dev --no-interaction --no-progress --with-all-dependencies \
    "drupal/core-dev:${coreVersion}" \
    'kint-php/kint:^6.0' \
    'php-parallel-lint/php-parallel-lint:^1.4' \
    'phpstan/phpstan-deprecation-rules:^2.0'; \
    composer clear-cache; \
    find /opt/drupal -xdev ! -type l ! -perm -g=w -not -path '*/node_modules/*' -exec chmod g+w {} +

# Package set fingerprint. The entrypoint runs drush updatedb when a site was
# last updated with a different one, so an image upgrade updates the database.
RUN md5sum /opt/drupal/composer.lock | cut -d' ' -f1 > /opt/drupal/.scs-packages-version

# Development also creates `developer` (host UID, in www-data) so an attached
# IDE can git/edit under /opt/drupal without root. PID 1 stays root (nginx,
# PHP-FPM); PHP-FPM workers stay www-data. www-data is in the `developer`
# group in turn: functional tests run as `developer` and create
# sites/simpletest/<id> as developer:developer 775, and PHP-FPM has to write
# into it. Fetches use HTTPS without keys; pushes go over SSH.
ARG DEV_UID=1000
ARG DEV_GID=1000
RUN set -eux; \
    if [ "$MODE" != "development" ]; then \
    exit 0; \
    fi; \
    groupadd --gid "${DEV_GID}" developer; \
    useradd --uid "${DEV_UID}" --gid developer --groups www-data \
    --create-home --home-dir /home/developer --shell /bin/bash developer; \
    usermod -aG developer www-data; \
    install -d -o developer -g developer /home/developer/.vscode-server /home/developer/.cursor-server; \
    git config --system --add url."git@git.drupal.org:".pushInsteadOf "https://git.drupalcode.org/"; \
    git config --system --add url."git@github.com:".pushInsteadOf "https://github.com/"

# Directories PHP-FPM writes to.
# - /var/scs-manager: private files (file_private_path); snapshots are mounted
#   below it.
# - /var/log/xdebug (development).
RUN set -eux; \
    install -d -o www-data -g www-data -m 775 /var/scs-manager; \
    if [ "$MODE" = "development" ]; then \
    install -d -o www-data -g www-data -m 775 /var/log/xdebug; \
    install -o www-data -g www-data -m 664 /dev/null /var/log/xdebug/xdebug.log; \
    fi; \
    mkdir -p /run/php

# Disable Git "dubious ownership" checks inside the container.
RUN git config --system --add safe.directory '*'

# Configuration imported on the first start.
COPY ./sync/configs/configs.tar.gz /tmp/configs.tar.gz
RUN set -eux; \
    mkdir -p /opt/drupal/sync/configs; \
    tar -xzf /tmp/configs.tar.gz -C /opt/drupal/sync/configs; \
    rm /tmp/configs.tar.gz; \
    chown -R www-data:www-data /opt/drupal/sync

# Redis settings, outside the sites volume so image updates reach existing
# sites. The entrypoint includes them from settings.php.
COPY ./configs/redis/redis.settings.php /var/configs/redis.settings.php

# PHP configuration. The shared files go to every image, the OPcache and
# Xdebug settings come from configs/php/<MODE>/. Copied after the Composer
# layers so changing a setting does not rebuild the codebase.
COPY ./configs/php/*.ini /usr/local/etc/php/conf.d/
COPY ./configs/php/${MODE}/ /usr/local/etc/php/conf.d/

# PHP-FPM pool (overrides the default zz-docker.conf).
COPY ./configs/php-fpm/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# NGINX configurations. Production logs nothing but errors.
COPY ./configs/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./configs/nginx/drupal.conf /etc/nginx/conf.d/drupal.conf
RUN set -eux; \
    rm -f /etc/nginx/conf.d/default.conf; \
    mkdir -p /run/nginx; \
    ln -sf /dev/stdout /var/log/nginx/access.log; \
    ln -sf /dev/stderr /var/log/nginx/error.log; \
    if [ "$MODE" = "production" ]; then \
    sed -i 's|access_log /var/log/nginx/access.log main;|access_log off;|' /etc/nginx/nginx.conf; \
    sed -i 's|error_log /var/log/nginx/error.log warn;|error_log off;|' /etc/nginx/nginx.conf; \
    fi

# Development helpers: scs-lint, its fallback configs, and the login-shell PATH.
COPY ./configs/dev/ /usr/local/share/scs-dev/
RUN set -eux; \
    if [ "$MODE" = "development" ]; then \
    install -m 755 /usr/local/share/scs-dev/scs-lint.sh /usr/local/bin/scs-lint; \
    install -m 644 /usr/local/share/scs-dev/scs-path.sh /etc/profile.d/scs-path.sh; \
    else \
    rm -rf /usr/local/share/scs-dev; \
    fi

COPY --chmod=755 entrypoint.sh /entrypoint.sh

EXPOSE 80

# Health check via the health_check module endpoint. Long start period: the
# first start installs and configures the whole site.
HEALTHCHECK --interval=15s --timeout=10s --start-period=10m --retries=10 \
    CMD curl -fsS http://localhost/health || exit 1

# tini as PID 1 for signal forwarding and zombie reaping. The entrypoint
# installs the site, starts PHP-FPM and then runs CMD (nginx).
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
