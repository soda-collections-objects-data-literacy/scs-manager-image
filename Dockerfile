FROM drupal:11.1.4-php8.3-apache-bookworm

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-manager-image.git
LABEL org.opencontainers.image.description "Plain Drupal with preinstalled Site and SODa SCS Manager."

# Install apts

RUN apt-get update; \
    apt-get install -y --no-install-recommends \
    default-mysql-client \
    git \
    libgmp-dev \
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

# Set memory settings for SCS Manager
RUN { \
    echo 'max_execution_time = 1200'; \
    echo 'max_input_time = 600'; \
    echo 'memory_limit = 1024M'; \
    echo 'upload_max_filesize = 1024M'; \
    echo 'max_file_uploads = 50'; \
    echo 'post_max_size = 1024M'; \
    } >> /usr/local/etc/php/conf.d/zz-scs-manager-recommended.ini;

# Enable output buffering
RUN { \
    echo 'output_buffering = on'; \
    } >> /usr/local/etc/php/conf.d/zz-drupal-recommended.ini;

# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    } >> /usr/local/etc/php/conf.d/zz-opcache-recommended.ini;


# Install drush
RUN composer require drush/drush

# add composer bin to PATH
RUN ln -s /opt/drupal/vendor/bin/drush /usr/local/bin/drush

RUN chown -R www-data:www-data /var/www/html

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
