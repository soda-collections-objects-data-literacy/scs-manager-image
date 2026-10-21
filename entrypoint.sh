#!/bin/bash
# Install the Drupal site with SCS Manager on the first start. The development
# image also prepares the `developer` user and the PHPUnit directories.
# Starts PHP-FPM, then runs CMD (nginx).

SETTINGS_FILE="/opt/drupal/web/sites/default/settings.php"
MODULE_DIR="/opt/drupal/web/modules/contrib/soda_scs_manager"
REDIS_SETTINGS_FILE="/var/configs/redis.settings.php"

# Package set fingerprint baked into the image and the one the site was last
# installed or updated with (on the sites volume).
IMAGE_PACKAGES_VERSION_FILE="/opt/drupal/.scs-packages-version"
SITE_PACKAGES_VERSION_FILE="/opt/drupal/web/sites/.scs-packages-version"

# Entrypoint Drush must not pay Xdebug overhead. PHP-FPM is started later and
# does not inherit this function, so IDE debugging still works.
drush() {
  XDEBUG_MODE=off command drush "$@"
}

is_development() {
  [ "${MODE}" = "development" ] && id developer >/dev/null 2>&1
}

# Development: keep `developer` on the host UID so bind-mounted clones and
# ~/.ssh are writable without copying keys. PID 1 stays root.
prepare_developer_user() {
  is_development || return 0

  local uid="${DEV_UID:-1000}" gid="${DEV_GID:-1000}"
  case "${uid}" in
    0|33)
      echo "DEV_UID=${uid} is reserved (root/www-data); leaving developer unchanged."
      ;;
    *)
      if [ "$(id -u developer)" != "${uid}" ]; then
        usermod -u "${uid}" developer
      fi
      if [ "$(id -g developer)" != "${gid}" ]; then
        if getent group "${gid}" >/dev/null; then
          usermod -g "${gid}" developer
          # PHP-FPM writes into the test sites `developer` creates.
          usermod -aG "$(getent group "${gid}" | cut -d: -f1)" www-data
        else
          groupmod -g "${gid}" developer
        fi
      fi
      ;;
  esac
  # Named IDE volumes keep the owner they were created with.
  chown developer:developer /home/developer /home/developer/.vscode-server /home/developer/.cursor-server 2>/dev/null || true

  # A clone under modules/custom (whole-codebase bind mounts) counts as well.
  if [ ! -f "${MODULE_DIR}/soda_scs_manager.info.yml" ] \
    && [ ! -f /opt/drupal/web/modules/custom/soda_scs_manager/soda_scs_manager.info.yml ]; then
    echo -e "\033[0;31mWARNING: ${MODULE_DIR} has no soda_scs_manager.info.yml.\033[0m"
    echo "Bind-mount an existing clone there, or use a named volume (Docker seeds it from the image)."
  fi
}

# Development: Drupal creates sites/simpletest/<id> itself but not the HTML
# output directory, and drops the page links without it.
prepare_phpunit() {
  is_development || return 0
  install -d -o developer -g www-data -m 2775 \
    /opt/drupal/web/sites/simpletest /opt/drupal/web/sites/simpletest/browser_output
}

# Run database updates when the image ships another package set than the one
# the site was installed or last updated with. Must run before anything that
# bootstraps the new code against the old schema (drush en, cache rebuilds).
# On failure the fingerprint stays, so the next start tries again.
update_database_if_packages_changed() {
  local image site
  image="$(cat "${IMAGE_PACKAGES_VERSION_FILE}" 2>/dev/null || echo unknown)"
  site="$(cat "${SITE_PACKAGES_VERSION_FILE}" 2>/dev/null || echo unknown)"
  if [ "${image}" = "${site}" ]; then
    return 0
  fi
  echo "Package set changed (${site} -> ${image}); running database updates..."
  if drush updatedb -y && drush cr; then
    echo "${image}" > "${SITE_PACKAGES_VERSION_FILE}"
    echo "Database updates applied."
  else
    echo -e "\033[0;31mERROR: drush updatedb failed; the site may not work until the updates run.\033[0m"
  fi
}

# Redis cache backend. settings.php includes the image's Redis settings once;
# sites from older images lack the include (theirs pointed at a
# settings.redis.php that never existed). The redis module is enabled once.
ensure_redis_cache() {
  if ! grep -q "${REDIS_SETTINGS_FILE}" "${SETTINGS_FILE}"; then
    cat >> "${SETTINGS_FILE}" << EOF

// Redis cache backend (scs-manager-image).
if (file_exists('${REDIS_SETTINGS_FILE}')) {
  include '${REDIS_SETTINGS_FILE}';
}
EOF
    echo "Redis settings included in settings.php."
  fi
  if ! drush pm:list --status=enabled --type=module --field=name 2>/dev/null | grep -qx redis; then
    echo "Enabling the redis module..."
    drush en redis -y && drush cr
  fi
}

# PHP-FPM owns the sites volume. Settings files are read-only; development
# keeps sites/default group-writable so `developer` can add
# settings.local.php. The codebase stays root-owned (see Dockerfile).
set_permissions() {
  chown -R www-data:www-data /opt/drupal/web/sites
  chown root:www-data /opt/drupal/web/sites/default "${SETTINGS_FILE}"
  chmod 444 "${SETTINGS_FILE}"
  if is_development; then
    chmod 775 /opt/drupal/web/sites/default
  else
    chmod 555 /opt/drupal/web/sites/default
  fi
}

prepare_developer_user

until mysql -h ${DB_HOST} -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "Waiting for MariaDB to be ready..."
  sleep 5
done

# Check if the site is already installed
if [ ! -f "${SETTINGS_FILE}" ]; then
  echo "Installing Drupal site..."
  # Install the site
  drush si \
    --db-url="${DB_DRIVER}://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --site-name="${DRUPAL_SITE_NAME}" \
    --account-name="${DRUPAL_USER}" \
    --account-pass="${DRUPAL_PASSWORD}"

  echo "Enabling modules..."
  # Enable companion theme first (hard dependency of soda_scs_manager), then modules
  drush theme:enable soda_scs_manager_theme gin -y
  drush config:set system.theme default soda_scs_manager_theme -y
  drush config:set system.theme admin gin -y
  # devel must never run in production.
  modules=(admin_toolbar book book_tree_menu ckeditor_font config_translation contact content_entity_sync content_translation custom_book_block entity_update field_group health_check imce language languageicons layout_builder layout_discovery linkit locale media media_library openid_connect pathauto pfdp soda_scs_manager single_content_sync smtp svg_image token)
  if is_development; then
    modules+=(devel)
  fi
  drush en "${modules[@]}" -y
  # Add German language and update translations
  drush language-add de -y
  drush locale:update -y
  # Disable single content sync UUID check
  drush config:set single_content_sync.settings site_uuid_check 0 -y
  # Clear cache
  drush cr

  # Single content sync package directory (composer installs module under contrib/)
  echo "\$settings['content_sync_directory'] = 'modules/contrib/soda_scs_manager/content/sync';" >> "${SETTINGS_FILE}"

  echo "Importing contents and configs..."
  # Import configurations
  drush config:import --partial --source=/opt/drupal/sync/configs -y
  drush content_entity_sync:import node --bundle=application,book,page
  drush content_entity_sync:import media --bundle=image
  drush content_entity_sync:import menu_link_content
  drush config:set system.site page.front /home -y
  if [ -f /opt/drupal/sync/configs/openid_connect.client.scs_sso.yml ]; then
    drush config:import /opt/drupal/sync/configs/openid_connect.client.scs_sso.yml -y
  fi

  echo "Extending settings.php"
  cat >> "$SETTINGS_FILE" << 'EOF'

$settings['file_private_path'] = '/var/scs-manager/';
EOF

  # Set proxy settings (if we are in a proxy environment)
  if [ -n "${DRUPAL_PROXY_ADDRESSES}" ]; then
    echo -e "\033[0;33mSETTING PROXY SETTINGS.\033[0m"
    {
      cat >> "$SETTINGS_FILE" << 'EOF'
      $settings["reverse_proxy"] = TRUE;
      $settings["reverse_proxy_trusted_headers"] = \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO;
      $settings['omit_vary_cookie'] = TRUE;
EOF
    ADDRESSES=$(printf '%s' "${DRUPAL_PROXY_ADDRESSES}" | sed 's/|/", "/g')
    printf '%s\n' "\$settings['reverse_proxy_addresses'] = [\"${ADDRESSES}\"];" >> "${SETTINGS_FILE}"
    } 1> /dev/null
    echo -e "\033[0;32mPROXY SETTINGS SET.\033[0m\n"
  else
    echo -e "\033[0;33mNO PROXY SETTINGS SET.\033[0m\n"
  fi

  ensure_redis_cache
  cp "${IMAGE_PACKAGES_VERSION_FILE}" "${SITE_PACKAGES_VERSION_FILE}"

  echo "Set permissions..."
  set_permissions

else
  echo "Site already installed"
  update_database_if_packages_changed
  ensure_redis_cache
fi

prepare_phpunit

# Ensure PHP-FPM socket directory exists
mkdir -p /run/php
chown www-data:www-data /run/php

# Start PHP-FPM in background
php-fpm -D

# Execute CMD (nginx)
exec "$@"
