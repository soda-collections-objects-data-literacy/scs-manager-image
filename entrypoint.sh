#!/bin/bash
# Install the Drupal site with SCS Manager

until mysql -h ${DB_HOST} -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "Waiting for MariaDB to be ready..."
  sleep 5
done

# Check if the site is already installed
if drush status | grep -q "Drupal bootstrap.*Successful"; then
  echo "Drupal site is already installed. Updating packages and fetching new git repository..."

  # Trust the git
  git config --global --add safe.directory /var/www/html/modules/custom/soda_scs_manager

  # Update packages
  composer update

  # Fetch the new git repository
  cd /var/www/html/modules/custom/soda_scs_manager
  git pull origin main

  # Clear cache
  drush cr
else
  echo "Installing Drupal site..."

  # Install the site
  drush si \
    --db-url="${DB_DRIVER}://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --site-name="${DRUPAL_SITE_NAME}" \
    --account-name="${DRUPAL_USER}" \
    --account-pass="${DRUPAL_PASSWORD}"

  # Install development modules
  composer require drupal/devel kint-php/kint
  drush en devel -y

  # Install and enable scs module
  git clone https://github.com/soda-collections-objects-data-literacy/soda_scs_manager.git /var/www/html/modules/custom/soda_scs_manager
  drush en soda_scs_manager -y
fi

# Set permissions
chown -R www-data:www-data /opt/drupal
chmod -R 775 /opt/drupal

# keep the container running
/usr/sbin/apache2ctl -D FOREGROUND