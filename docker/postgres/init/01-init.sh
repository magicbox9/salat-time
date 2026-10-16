#!/bin/sh
# Runs once, when the database volume is first created, as the superuser.
#  - extensions in the app database and the test database
#  - a NON-superuser role the application connects as
set -eu

APP_USER="${APP_DB_USERNAME:-salat_app}"
APP_PASS="${APP_DB_PASSWORD:?APP_DB_PASSWORD must be set}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
CREATE ROLE "$APP_USER" LOGIN PASSWORD '$APP_PASS' NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE DATABASE salat_testing;
SQL

for db in "$POSTGRES_DB" salat_testing; do
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<SQL
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- fuzzy mosque / city search
CREATE EXTENSION IF NOT EXISTS unaccent;    -- accent-insensitive search (Évry = Evry)
CREATE EXTENSION IF NOT EXISTS citext;      -- case-insensitive emails
CREATE EXTENSION IF NOT EXISTS cube;        -- needed by earthdistance
CREATE EXTENSION IF NOT EXISTS earthdistance; -- nearest-mosque queries
ALTER DATABASE "$db" OWNER TO "$APP_USER";
ALTER SCHEMA public OWNER TO "$APP_USER";
SQL
done
