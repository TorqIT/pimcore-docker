FROM pimcore/pimcore:php8.2-v3 as base
ARG CUSTOM_LINUX_PACKAGES
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends vim supervisor netcat-traditional default-mysql-client ${CUSTOM_LINUX_PACKAGES}; \
    rm -rf /var/lib/apt/lists/*; \
    usermod -u 1000 www-data; \
    groupmod -g 1000 www-data;
# We copy in the composer files and download dependencies, then in a separate set of statements below copy in the full
# source directory and run a full composer install. This will take advantage of Docker-build caching when composer
# dependencies do not change.
COPY --chown=www-data:www-data --from=composer-json-src /pimcore-root/composer.json /var/www/html/composer.json
COPY --chown=www-data:www-data --from /pimcore-root/composer.lock /var/www/html/composer.lock
COPY /docker/composer-install-dependencies.sh /composer-install-dependencies.sh
RUN /composer-install-dependencies.sh
COPY --chown=www-data:www-data /pimcore-root /var/www/html
RUN cd /var/www/html; \
    runuser -u www-data -- php /usr/local/bin/composer install

FROM base as init
ARG PIMCORE_BUNDLES
ENV PIMCORE_BUNDLES=${PIMCORE_BUNDLES}
COPY /docker/init/init.sh /init.sh
CMD [ "/init.sh" ]

# Default sources for config files
FROM base as php-ini-src
COPY /php-fpm/docker-pimcore-php.ini /usr/local/etc/php/conf.d/docker-pimcore-php.ini
FROM base as nginx-conf-src
COPY /php-fpm/nginx.conf /etc/nginx/sites-available/default
FROM base as supervisord-conf-src
COPY /supervisord/supervisord.conf /etc/supervisor/conf.d/pimcore.conf

FROM base as php-fpm
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends nginx; \
    rm -rf /var/lib/apt/lists/*;
# TODO what to specify as "source path" when copying from either stage or context?
COPY --from=php-ini-src . /usr/local/etc/php/conf.d/docker-pimcore-php.ini
COPY --from=nginx-conf-src . etc/nginx/sites-available/default
COPY /php-fpm/supervisord.conf /etc/supervisor/supervisord.conf
COPY /php-fpm/start-php.sh /start-php.sh
RUN runuser -u www-data -- /var/www/html/bin/console pimcore:build:classes; \
    runuser -u www-data -- /var/www/html/bin/console cache:warmup
CMD [ "/start-php.sh" ]

FROM base as supervisord
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends cron; \
    rm -rf /var/lib/apt/lists/*;
COPY --from=pimcore/pimcore:php8.2-supervisord-v3 /var/run /var/run
COPY --from=pimcore/pimcore:php8.2-supervisord-v3 /usr/sbin/cron /usr/sbin/cron
COPY --from=pimcore/pimcore:php8.2-supervisord-v3 /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY --from=supervisord-conf-src /etc/supervisor/conf.d/pimcore.conf /etc/supervisor/conf.d/pimcore.conf
COPY /supervisord/start-supervisord.sh /start-supervisord.sh
RUN runuser -u www-data -- /var/www/html/bin/console pimcore:build:classes; \
    runuser -u www-data -- /var/www/html/bin/console cache:warmup
CMD [ "/start-supervisord.sh" ]

FROM base as php-fpm-debug
COPY --from=pimcore/pimcore:php8.2-debug-v3 /usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN pecl install xdebug; \
    docker-php-ext-enable xdebug;
ENV PHP_IDE_CONFIG serverName=localhost
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
