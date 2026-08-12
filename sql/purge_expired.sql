-- localclaw - retention purge.
--
-- Deletes work-memory rows whose retention window has elapsed. Run this
-- during an active, interactive session (there is deliberately NO unattended
-- cleanup schedule). BEGIN IMMEDIATE takes a write lock up front so the whole
-- purge is a single consistent transaction.

PRAGMA busy_timeout = 5000;

BEGIN IMMEDIATE;
DELETE FROM action_log WHERE retention_until <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now');
DELETE FROM follow_up  WHERE retention_until <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now');
COMMIT;
