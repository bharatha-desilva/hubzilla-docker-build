FROM composer:latest as hubzilla-builder

WORKDIR /tmp/build/hubzilla
COPY composer.json composer.lock .htaccess ./
RUN composer install --no-dev --no-interaction --optimize-autoloader
RUN composer dump-autoload -o
COPY . .
RUN util/add_addon_repo https://framagit.org/hubzilla/addons.git hzaddons
RUN util/update_addon_repo hzaddons

FROM php:apache
WORKDIR /var/www/html
COPY --from=hubzilla-builder /tmp/build/hubzilla ./
RUN mkdir -p 'store/[data]/smarty3'
RUN chmod -R 777 store
RUN chmod -R 777 .htaccess
RUN a2enmod rewrite
RUN apt-get update && apt-get install -y \
		libfreetype6-dev \
		libjpeg62-turbo-dev \
		libzip-dev \
		libpq-dev \
		sendmail \
	&& docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
	&& docker-php-ext-install -j$(nproc) gd \
	&& docker-php-ext-install -j$(nproc) zip \
	&& docker-php-ext-install -j$(nproc) pdo pdo_pgsql pgsql

RUN echo "sendmail_path=/usr/sbin/sendmail -t -i" >> /usr/local/etc/php/conf.d/sendmail.ini
RUN sed -i '/#!\/bin\/sh/aservice sendmail restart' /usr/local/bin/docker-php-entrypoint
RUN sed -i '/#!\/bin\/sh/aecho "$(hostname -i)\t$(hostname) $(hostname).localhost" >> /etc/hosts' /usr/local/bin/docker-php-entrypoint

# And clean up the image
RUN rm -rf /var/lib/apt/lists/*

