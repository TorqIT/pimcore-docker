#!/usr/bin/env bash 

set -e

until nc -z -v -w30 $DATABASE_HOST $DATABASE_PORT
do
  echo "Waiting for database connection..."
  sleep 5
done

# TODO extra condition to make extra-sure this doesn't run in non-local envs
if [ "$(mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" -p"$DATABASE_PASSWORD" \
      -sse "select count(*) from information_schema.tables where table_schema='pimcore' and table_name='assets';")" -eq 0 ]
then
  echo "Database is empty, so doing a fresh install to seed the database..."
  runuser -u www-data -- vendor/bin/pimcore-install \
    --admin-username=admin \
    --admin-password="$PIMCORE_ADMIN_PASSWORD" \
    --mysql-host-socket="$DATABASE_HOST" \
    --mysql-port="$DATABASE_PORT" \
    --mysql-database="$DATABASE_NAME" \
    --mysql-username="$DATABASE_USER" \
    --mysql-password="$DATABASE_PASSWORD" \
    --skip-database-config
fi

echo Installing bundles...
# TODO use env var as list of bundles to install
# runuser -u www-data -- /var/www/html/bin/console pimcore:bundle:install $bundle

echo Running migration...
runuser -u www-data -- /var/www/html/bin/console doctrine:migrations:migrate -n

echo Rebuilding classes...
runuser -u www-data -- /var/www/html/bin/console pimcore:deployment:classes-rebuild -c -d -n

echo Generating roles...
runuser -u www-data -- /var/www/html/bin/console torq:generate-roles

echo Generating folders...
# TODO folder creator
