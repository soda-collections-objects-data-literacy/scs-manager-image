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

  # Single content sync package directory (relative to web root)
  echo "\$settings['content_sync_directory'] = 'modules/custom/soda_scs_manager/content/sync';" >> /opt/drupal/web/sites/default/settings.php

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
  # Set config sync directory
  configFile="/opt/drupal/web/sites/default/settings.php"
  echo "
if (file_exists(\$app_root . '/' . \$site_path . '/settings.redis.php')) {
  include \$app_root . '/' . \$site_path . '/settings.redis.php';
}
" >> \$configFile

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
