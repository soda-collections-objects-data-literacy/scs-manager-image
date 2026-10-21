<?php

/**
 * Redis cache backend configuration for the SCS Manager.
 *
 * Based on official documentation: https://project.pages.drupalcode.org/redis/
 *
 * settings.php includes this file (the entrypoint adds the include). $app_root
 * and $class_loader come from the settings.php scope.
 * Do not probe Redis here: a connect timeout would delay every bootstrap
 * (entrypoint Drush and web) when Redis is slow or down.
 */

if (!extension_loaded('redis')) {
  return;
}

$redisModule = $app_root . '/modules/contrib/redis';
$redisHost = getenv('REDIS_HOST') ?: 'redis';
$redisPort = getenv('REDIS_PORT') ?: 6379;

// https://project.pages.drupalcode.org/redis/#common-configuration
$settings['redis.connection']['interface'] = 'PhpRedis';
$settings['redis.connection']['host'] = $redisHost;
$settings['redis.connection']['port'] = $redisPort;
$settings['redis.connection']['persistent'] = TRUE;

// Keep the database cache for the form cache bin (required for Drupal).
if (is_file($redisModule . '/redis.services.yml')) {
  $settings['cache']['default'] = 'cache.backend.redis';
  $settings['cache']['bins']['form'] = 'cache.backend.database';
  $settings['cache']['bins']['bootstrap'] = 'cache.backend.redis';
  $settings['cache']['bins']['render'] = 'cache.backend.redis';
  $settings['cache']['bins']['data'] = 'cache.backend.redis';
  $settings['cache']['bins']['discovery'] = 'cache.backend.redis';
  $settings['container_yamls'][] = $redisModule . '/redis.services.yml';
}

// Lock, flood and queue backends.
if (is_file($redisModule . '/example.services.yml')) {
  $settings['container_yamls'][] = $redisModule . '/example.services.yml';
}

// Compress entries above 100 bytes, keep expired items for an hour, and treat
// invalidateAll() as deleteAll().
// https://project.pages.drupalcode.org/redis/#cache-optimizations
$settings['redis_compress_length'] = 100;
$settings['redis_compress_level'] = 1;
$settings['redis_ttl_offset'] = 3600;
$settings['redis_invalidate_all_as_delete'] = TRUE;

// Bootstrap container on Redis. The class loader does not know the module
// namespace yet at this point.
if (is_dir($redisModule . '/src') && isset($class_loader)) {
  $class_loader->addPsr4('Drupal\\redis\\', $redisModule . '/src');
  if (class_exists('Drupal\redis\ClientFactory')) {
    $settings['bootstrap_container_definition'] = [
      'parameters' => [],
      'services' => [
        'redis.factory' => [
          'class' => 'Drupal\redis\ClientFactory',
        ],
        'cache.backend.redis' => [
          'class' => 'Drupal\redis\Cache\CacheBackendFactory',
          'arguments' => ['@redis.factory', '@cache_tags_provider.container', '@serialization.phpserialize'],
        ],
        'cache.container' => [
          'class' => '\Drupal\redis\Cache\PhpRedis',
          'factory' => ['@cache.backend.redis', 'get'],
          'arguments' => ['container'],
        ],
        'cache_tags_provider.container' => [
          'class' => 'Drupal\redis\Cache\RedisCacheTagsChecksum',
          'arguments' => ['@redis.factory'],
        ],
        'serialization.phpserialize' => [
          'class' => 'Drupal\Component\Serialization\PhpSerialize',
        ],
      ],
    ];
  }
}
