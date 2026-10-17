FROM php:8.4-fpm-alpine

# Extension installer (handles build deps for every extension)
COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
      pdo_pgsql pgsql redis intl zip gd bcmath opcache pcntl exif sockets \
 && apk add --no-cache git unzip bash postgresql-client ffmpeg

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

COPY php.ini /usr/local/etc/php/conf.d/zz-salat.ini

WORKDIR /var/www/html
