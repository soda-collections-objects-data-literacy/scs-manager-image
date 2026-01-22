ARG DRUPAL_IMAGE=11.3.2-php8.3-fpm-bookworm
ARG MODE=production

FROM drupal:${DRUPAL_IMAGE:-11.3.2-php8.3-fpm-bookworm}

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-manager-image.git
LABEL org.opencontainers.image.description="Plain Drupal with preinstalled Site and SODa SCS Manager."

# Install apts
RUN apt-get update; \
    apt-get install -y --no-install-recommends \
    curl \
    default-mysql-client \
    git \
    imagemagick \
    libaom3 \
    libavif-dev \
    libavif15 \
    libdav1d6 \
    libfreetype6-dev \
    libgmp-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    nginx \
    sendmail \
    unzip \
    vim \
    wget

# Upload progress
RUN	set -eux; \
git clone https://github.com/php/pecl-php-uploadprogress/ /usr/src/php/ext/uploadprogress/; \
docker-php-ext-configure uploadprogress; \
docker-php-ext-install uploadprogress; \
rm -rf /usr/src/php/ext/uploadprogress;

# GMP
RUN docker-php-ext-install gmp

# Configure and install GD extension with AVIF support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif \
    && docker-php-ext-install -j$(nproc) gd

# Install intl
RUN set -eux; \
    docker-php-ext-configure intl \
    && docker-php-ext-install intl;

# Redis
# Install Redis extension
RUN set -eux; \
    pecl install redis; \
    docker-php-ext-enable redis;

# Add Redis config
RUN { \
    echo 'redis.session.locking_enabled=1'; \
    echo 'redis.session.lock_retries=100'; \
    echo 'redis.session.lock_wait_time=5000'; \
    echo 'session.save_handler = redis'; \
    echo 'session.save_path = "tcp://redis:6379?database=2"'; \
    } >> /usr/local/etc/php/conf.d/zz-redis-custom.ini;

# Add Redis settings
COPY ./configs/redis/redis.settings.php /opt/drupal/web/sites/default/redis.settings.php

    # Install apcu
RUN set -eux; \
pecl install apcu;

# Add php configs
RUN { \
    echo 'extension=apcu.so'; \
    echo "apc.enable_cli=1"; \
    echo "apc.enable=1"; \
    echo "apc.shm_size=32M"; \
    } >> /usr/local/etc/php/conf.d/zz-apcu-custom.ini;

# Install xdebug if mode is development
RUN if [ "$MODE" = "development" ]; then \
    pecl install xdebug && docker-php-ext-enable xdebug; \
    fi

# Create xdebug log directory
# @todo: This is a hack to get around the fact that the xdebug log directory is not writable by the www-data user. CHANGE ME IN FUTURE
RUN if [ "$MODE" = "development" ]; then \
    mkdir -p /var/log/xdebug; \
    chown www-data:www-data /var/log/xdebug; \
    chmod 775 /var/log/xdebug; \
    fi

# Add xdebug config if mode is development
RUN if [ "$MODE" = "development" ]; then \
    { \
    echo 'xdebug.mode=debug,develop'; \
    echo 'xdebug.client_host=host.docker.internal'; \
    echo 'xdebug.start_with_request=trigger'; \
    echo 'xdebug.trigger_value=scs'; \
    echo 'xdebug.client_port=9003'; \
    echo 'xdebug.log=/var/log/xdebug/xdebug.log'; \
    echo 'xdebug.log_level=7'; \
    echo 'xdebug.idekey=scs'; \
    echo 'xdebug.discover_client_host=1'; \
    echo 'error_reporting=E_ALL'; \
    } >> /usr/local/etc/php/conf.d/zz-xdebug-custom.ini;\
    fi

# Set memory settings for SCS Manager
RUN { \
    echo 'max_execution_time = 1200'; \
    echo 'max_input_time = 600'; \
    echo 'memory_limit = 1024M'; \
    echo 'max_file_uploads = 50'; \
    echo 'output_buffering = on'; \
    echo 'post_max_size = 1024M'; \
    echo 'upload_max_filesize = 1024M'; \
    } >> /usr/local/etc/php/conf.d/zz-scs-manager-recommended.ini;

# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.fast_shutdown=1'; \
    } >> /usr/local/etc/php/conf.d/zz-opcache-recommended.ini;

# Add opcache config if mode is production
RUN if [ "$MODE" = "development" ]; then \
    { \
    echo 'opcache.revalidate_freq=0'; \
    } >> /usr/local/etc/php/conf.d/zz-opcache-recommended.ini;\
    fi

# Install drush
RUN set -eux; \
    cd /opt/drupal && \
    composer require \
    'drupal/admin_toolbar:^3.6' \
    'drupal/book:^2.0' \
    'drupal/book_tree_menu:^3.0' \
    'drupal/bootstrap5:^4.0' \
    'drupal/ckeditor_font:^2.0@beta' \
    'drupal/coder:^8.3' \
    'drupal/content_entity_sync:^2.3' \
    'drupal/core-composer-scaffold:^11.3' \
    'drupal/core-project-message:^11.3' \
    'drupal/core-recommended:^11.3' \
    'drupal/custom_book_block:^2.0' \
    'drupal/devel:^5.3' \
    'drupal/entity_update:^3.0' \
    'drupal/field_group:^4.0' \
    'drupal/gin:^5.0' \
    'drupal/health_check:^3.1' \
    'drupal/imce:^3.1' \
    'drupal/languageicons:^2.0@beta' \
    'drupal/linkit:^7.0' \
    'drupal/openid_connect:^3.0@alpha' \
    'drupal/pathauto:^1.13' \
    'drupal/private_files_download_permission:^3.1' \
    'drupal/redis:^1.11' \
    'drupal/single_content_sync:^1.4' \
    'drupal/smtp:^1.4' \
    'drupal/svg_image:^3.2' \
    'drupal/token:^1.17' \
    'drush/drush:^13.5' \
    'kint-php/kint:^6.0';

# Actually install the packages
RUN composer install --no-interaction

# Install and enable scs module
RUN git clone --branch main https://github.com/soda-collections-objects-data-literacy/soda_scs_manager.git /opt/drupal/web/modules/custom/soda_scs_manager
RUN git config --global --add safe.directory /opt/drupal/web/modules/custom/soda_scs_manager

# add composer bin to PATH
RUN ln -s /opt/drupal/vendor/bin/drush /usr/local/bin/drush

RUN mkdir -p /opt/drupal/sync/configs
RUN chown -R www-data:www-data /opt/drupal/sync

COPY ./sync/configs/configs.tar.gz /opt/drupal/sync/configs.tar.gz
RUN tar -xzf /opt/drupal/sync/configs.tar.gz -C /opt/drupal/sync/configs
RUN rm /opt/drupal/sync/configs.tar.gz
RUN chown -R www-data:www-data /var/www/html

# PHP-FPM performance pool config
RUN mkdir -p /run/php

# Copy custom pool config (override the default zz-docker.conf)
COPY ./configs/php-fpm/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# Copy NGINX configurations
COPY ./configs/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./configs/nginx/drupal.conf /etc/nginx/conf.d/drupal.conf
RUN rm -f /etc/nginx/conf.d/default.conf && \
    mkdir -p /run/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# In production mode, disable NGINX access logging except for errors.
RUN if [ "$MODE" = "production" ]; then \
      sed -i 's|access_log /var/log/nginx/access.log main;|access_log off;|' /etc/nginx/nginx.conf && \
      sed -i 's|error_log /var/log/nginx/error.log warn;|error_log off;|' /etc/nginx/nginx.conf; \
    fi

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
