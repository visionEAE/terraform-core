-- One-shot Cloud SQL bootstrap: everything infra/init-db does locally, minus role creation
-- (Terraform's google_sql_user owns that, with passwords from Secret Manager). Idempotent —
-- safe to re-run. Executed as the postgres user through the bastion tunnel by db-init.sh.
--
-- Cloud SQL quirk: postgres is not a superuser, so it may only ALTER an object's owner to a
-- role it is a member of — hence the GRANT role TO postgres lines before each ownership change.

\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS lms;
CREATE SCHEMA IF NOT EXISTS support;
CREATE SCHEMA IF NOT EXISTS network;
CREATE SCHEMA IF NOT EXISTS audit;

REVOKE ALL ON SCHEMA public FROM PUBLIC;

GRANT auth_user    TO postgres;
GRANT core_user    TO postgres;
GRANT lms_user     TO postgres;
GRANT support_user TO postgres;
GRANT network_user TO postgres;
GRANT dwh_relay    TO postgres;

ALTER SCHEMA auth    OWNER TO auth_user;
ALTER SCHEMA core    OWNER TO core_user;
ALTER SCHEMA lms     OWNER TO lms_user;
ALTER SCHEMA support OWNER TO support_user;
ALTER SCHEMA network OWNER TO network_user;

ALTER ROLE auth_user    SET search_path = auth;
ALTER ROLE core_user    SET search_path = core;
ALTER ROLE lms_user     SET search_path = lms;
ALTER ROLE support_user SET search_path = support;
ALTER ROLE network_user SET search_path = network;

-- The audit trail is owned by the infrastructure, not by any service; the engine — not
-- application code — guarantees it is append-only (INSERT + SELECT, never UPDATE/DELETE).
CREATE TABLE IF NOT EXISTS audit.audit_record (
    id                   BIGSERIAL PRIMARY KEY,
    occurred_at          TIMESTAMPTZ  NOT NULL,
    request_id           TEXT         NOT NULL,
    trace_id             TEXT,
    service_name         TEXT         NOT NULL,
    record_type          TEXT         NOT NULL,
    action               TEXT         NOT NULL,
    actor_id             UUID,
    actor_roles          TEXT[],
    subject_type         TEXT,
    subject_id           TEXT,
    authorization_basis  TEXT,
    outcome              TEXT         NOT NULL,
    source_ip            TEXT,
    details              JSONB,
    CONSTRAINT chk_audit_record_type    CHECK (record_type IN ('DATA_ACCESS', 'SECURITY', 'STATE_CHANGE')),
    CONSTRAINT chk_audit_record_outcome CHECK (outcome IN ('ALLOWED', 'DENIED'))
);

CREATE INDEX IF NOT EXISTS idx_audit_record_request_id ON audit.audit_record (request_id);
CREATE INDEX IF NOT EXISTS idx_audit_record_subject    ON audit.audit_record (subject_type, subject_id, occurred_at DESC);

GRANT USAGE ON SCHEMA audit TO auth_user, core_user, lms_user, support_user, network_user;
GRANT INSERT, SELECT ON audit.audit_record TO auth_user, core_user, lms_user, support_user, network_user;
GRANT USAGE ON SEQUENCE audit.audit_record_id_seq TO auth_user, core_user, lms_user, support_user, network_user;
-- Deliberately absent: UPDATE, DELETE, TRUNCATE.

-- The DWH relay reads and marks the outbox tables of support and network. Default privileges
-- (rather than table grants) because Flyway creates outbox_event AFTER this script runs, at each
-- service's first boot. Broader than one table per schema — acceptable for the POC, and the
-- schemas contain little else.
GRANT USAGE ON SCHEMA support TO dwh_relay;
GRANT USAGE ON SCHEMA network TO dwh_relay;
ALTER DEFAULT PRIVILEGES FOR ROLE support_user IN SCHEMA support GRANT SELECT, UPDATE ON TABLES TO dwh_relay;
ALTER DEFAULT PRIVILEGES FOR ROLE network_user IN SCHEMA network GRANT SELECT, UPDATE ON TABLES TO dwh_relay;
-- In case the services booted before this script ever ran:
GRANT SELECT, UPDATE ON ALL TABLES IN SCHEMA support TO dwh_relay;
GRANT SELECT, UPDATE ON ALL TABLES IN SCHEMA network TO dwh_relay;
