#!/bin/bash
# Install the Drupal site with SCS Manager

until mysql -h ${DB_HOST} -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "Waiting for MariaDB to be ready..."
  sleep 5
done

# Check if the site is already installed
if [ ! -f /opt/drupal/web/sites/default/settings.php ]; then
  echo "Installing Drupal site..."
  # Install the site
  drush si \
    --db-url="${DB_DRIVER}://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --site-name="${DRUPAL_SITE_NAME}" \
    --account-name="${DRUPAL_USER}" \
    --account-pass="${DRUPAL_PASSWORD}"

  echo "Enabling modules..."
  # Enable modules
  drush en admin_toolbar book book_tree_menu ckeditor_font config_translation contact content_entity_sync content_translation custom_book_block devel entity_update field_group health_check imce language languageicons linkit locale media media_library openid_connect pathauto pfdp soda_scs_manager single_content_sync smtp svg_image token -y
  # Enable theme and set admin theme
  drush theme:enable gin
  drush config:set system.theme admin gin -y
  # Add German language and update translations
  drush language-add de -y
  drush locale:update -y
  # Disable single content sync UUID check
  drush config:set single_content_sync.settings site_uuid_check 0 -y
  # Clear cache
  drush cr

  echo "Importing contents and configs..."
  # Import configurations
  drush config:import --partial --source=/opt/drupal/sync/configs -y
  drush content:import modules/custom/soda_scs_manager/content/contents.zip
  drush config:set system.site page.front /home -y

  echo "Extending settings.php"
  # Set config sync directory and private path
  configFile="/opt/drupal/web/sites/default/settings.php"
  echo "
if (file_exists(\$app_root . '/' . \$site_path . '/settings.redis.php')) {
  include \$app_root . '/' . \$site_path . '/settings.redis.php';
}
$settings['file_private_path'] = '/var/scs-manager/';
" >> \$configFile

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

  echo "Set permissions..."
  # Set permissions
  chown -R www-data:www-data /opt/drupal
  chmod -R 775 /opt/drupal

else
  echo "Site already installed"
fi

# Ensure PHP-FPM socket directory exists
mkdir -p /run/php
chown www-data:www-data /run/php

# Start PHP-FPM in background
php-fpm -D

# Execute CMD (nginx)
exec "$@"
