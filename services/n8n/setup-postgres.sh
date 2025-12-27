#!/usr/bin/env bash
# Helper script to set up PostgreSQL database and user for n8n
# Run this on the PostgreSQL container: sudo -u postgres bash services/n8n/setup-postgres.sh

set -euo pipefail

DB_NAME="${DB_POSTGRESDB_DATABASE:-n8n}"
DB_USER="${DB_POSTGRESDB_USER:-n8n}"
DB_PASSWORD="${DB_POSTGRESDB_PASSWORD:-CHANGEME}"

echo "[*] Creating PostgreSQL user and database for n8n..."

psql <<SQL
-- Create user
CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';

-- Create database
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};

-- Connect to the database
\c ${DB_NAME}

-- Make sure DB owner is n8n (if set owner was not processed on creation)
ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};

-- Make schema public owned by n8n inside the n8n DB
ALTER SCHEMA public OWNER TO ${DB_USER};

-- Ensure permissions (safe even if owner is set)
GRANT USAGE, CREATE ON SCHEMA public TO ${DB_USER};

-- Helpful grants for existing objects (harmless if none exist yet)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};

-- Ensure future objects created by the migration role are accessible
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
SQL

echo "[✓] PostgreSQL setup complete for n8n"

