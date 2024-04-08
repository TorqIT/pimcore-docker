FROM pimcore/pimcore:php8.2-v3 as base

RUN set -eux; \
    apt update; \
    apt install -y --no-install-recommends vim nginx supervisor netcat-traditional net-tools iputils-ping default-mysql-client; \
    rm -rf /var/lib/apt/lists/*; \
    usermod -u 1000 www-data; \
    groupmod -g 1000 www-data; 

ARG $PHP_MEMORY_LIMIT=3G
ARG $PHP_UPLOAD_MAX_FILESIZE=10G
ARG $PHP_POST_MAX_SIZE=10G
ARG $PHP_MAX_EXECUTION_TIME=0
ARG $PHP_MAX_INPUT_TIME=-1
ARG $PHP_SESSION_SAVE_HANDLER=redis
ARG $PHP_SESSION_SAVE_PATH="tcp://${REDIS_HOST}:6379?database=${REDIS_SESSION_DB}"
ENV $PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT}
ENV $PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE}
ENV $PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE}
ENV $PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME}
ENV $PHP_MAX_INPUT_TIME=${PHP_MAX_INPUT_TIME}
ENV $PHP_SESSION_SAVE_HANDLER=${PHP_SESSION_SAVE_HANDLER}
ENV $PHP_SESSION_SAVE_PATH=${PHP_SESSION_SAVE_PATH}
COPY /base/php.ini /usr/local/etc/php/conf.d/php.ini

FROM base as php
COPY /php/supervisord.conf /etc/supervisor/supervisord.conf
COPY /php/nginx.conf /etc/nginx/sites-available/default
# TODO basic PHP FPM ini
CMD ["/usr/bin/supervisord"]

FROM base as supervisord
RUN set -eux; \
    apt update; \
    apt install -y cron; \
    chmod gu+rw /var/run; \
    chmod gu+s /usr/sbin/cron; \
    rm -rf /var/lib/apt/lists/*;
COPY /supervisord/supervisord.conf /etc/supervisor/supervisord.conf
CMD ["/usr/bin/supervisord"]
