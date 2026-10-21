# Login shells reset PATH in /etc/profile and drop the image ENV, so
# phpcs, phpstan, phpunit and the other Composer bins disappear for
# developer and in-container agents. Appended like the image ENV, so
# /usr/local/bin/composer stays ahead of the copy core-dev puts in vendor/bin.
case ":${PATH}:" in
  *:/opt/drupal/vendor/bin:*) ;;
  *) export PATH="${PATH}:/opt/drupal/vendor/bin" ;;
esac
