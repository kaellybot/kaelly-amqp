-- =============================================================================
-- Game isolation — consolidated migration
-- Spec: docs/specs/game-isolation.md (M1-A, M1-B, M2, M3, M4)
--
-- ASSUMPTION: every pod is stopped while this runs.
--   That is what allows M3 (dropping emojis.snowflake / snowflake_dev) to run in
--   the same pass as M2, instead of waiting for every reader to be migrated
--   first. Nothing may read the old emoji columns after section 5.
--
-- ORDER OF THE WHOLE OPERATION:
--   1. Back up the database (structure AND data).
--   2. Stop every pod.
--   3. Run section 0 and fix anything it reports. Do not continue otherwise.
--   4. Run sections 1 to 5 (the DDL).
--   5. Run section 6 and check every count is 0.
--   6. Deploy every service at its game-aware version, INCLUDING the emoji
--      changes (EMO-2 in kaelly-discord, EMO-3 in Kaelly-notifier). Code that
--      still reads emojis.snowflake will not start working again.
--   7. Start the pods.
--   8. Only then insert Touch reference data (§5.2) and Touch emoji snowflakes.
--
-- DDL IS NOT TRANSACTIONAL in MySQL: if a statement fails, the ones before it
-- stay applied. Restore from the backup rather than re-running blindly.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. PRE-CHECKS — every row below must be 0. Fix the data before continuing.
-- -----------------------------------------------------------------------------

-- 0.a A row with game 0 can never be published once the AMQP guards are on.
SELECT 'guilds' AS table_name, COUNT(*) AS bad_rows FROM guilds WHERE game = 0
UNION ALL SELECT 'channel_servers',   COUNT(*) FROM channel_servers   WHERE game = 0
UNION ALL SELECT 'webhook_almanaxes', COUNT(*) FROM webhook_almanaxes WHERE game = 0
UNION ALL SELECT 'webhook_feeds',     COUNT(*) FROM webhook_feeds     WHERE game = 0
UNION ALL SELECT 'webhook_twitters',  COUNT(*) FROM webhook_twitters  WHERE game = 0
UNION ALL SELECT 'alignment_books',   COUNT(*) FROM alignment_books   WHERE game = 0
UNION ALL SELECT 'job_books',         COUNT(*) FROM job_books         WHERE game = 0
UNION ALL SELECT 'feed_sources',      COUNT(*) FROM feed_sources      WHERE game = 0
UNION ALL SELECT 'twitter_accounts',  COUNT(*) FROM twitter_accounts  WHERE game = 0
UNION ALL SELECT 'almanax_news',      COUNT(*) FROM almanax_news      WHERE game = 0
UNION ALL SELECT 'sets',              COUNT(*) FROM sets              WHERE game = 0;

-- 0.b Rows that would violate the composite foreign keys created below.
SELECT 'servers.game out of range' AS check_name, COUNT(*) AS bad_rows
  FROM servers WHERE game NOT IN (1, 2, 3)
UNION ALL SELECT 'guilds -> servers game mismatch', COUNT(*)
  FROM guilds x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game
UNION ALL SELECT 'channel_servers -> servers game mismatch', COUNT(*)
  FROM channel_servers x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game
UNION ALL SELECT 'job_books -> servers game mismatch', COUNT(*)
  FROM job_books x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game
UNION ALL SELECT 'alignment_books -> servers game mismatch', COUNT(*)
  FROM alignment_books x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game
UNION ALL SELECT 'webhook_twitters -> twitter_accounts game mismatch', COUNT(*)
  FROM webhook_twitters w JOIN twitter_accounts t ON t.id = w.twitter_id WHERE t.game <> w.game;

-- 0.c M4 needs a complete date on every almanax row.
SELECT 'almanaxes with no date' AS check_name, COUNT(*) AS bad_rows
  FROM almanaxes WHERE month IS NULL OR day IS NULL;


-- -----------------------------------------------------------------------------
-- 1. M1-A — servers / server_labels keyed by (id, game)
--
-- restrict_fk_on_non_standard_key is ON by default: a foreign key must reference
-- a full primary or unique key, so every FK to servers(id) is dropped before the
-- primary key changes, then recreated on (id, game).
-- -----------------------------------------------------------------------------

ALTER TABLE server_labels   DROP FOREIGN KEY fk_servers_labels;
ALTER TABLE server_labels   DROP INDEX fk_servers_labels;
ALTER TABLE guilds          DROP FOREIGN KEY fk_guilds_server;
ALTER TABLE guilds          DROP INDEX fk_guilds_server;
ALTER TABLE channel_servers DROP FOREIGN KEY fk_channel_servers_server;
ALTER TABLE channel_servers DROP INDEX fk_channel_servers_server;
ALTER TABLE job_books       DROP FOREIGN KEY fk_job_books_server;
ALTER TABLE job_books       DROP INDEX fk_job_books_server;
ALTER TABLE alignment_books DROP FOREIGN KEY fk_alignment_books_server;
ALTER TABLE alignment_books DROP INDEX fk_alignment_books_server;

ALTER TABLE servers DROP PRIMARY KEY, ADD PRIMARY KEY (id, game);

ALTER TABLE server_labels ADD COLUMN game INT NOT NULL DEFAULT 1 AFTER server_id;
UPDATE server_labels sl JOIN servers s ON s.id = sl.server_id SET sl.game = s.game;
ALTER TABLE server_labels DROP PRIMARY KEY, ADD PRIMARY KEY (server_id, game, locale);

ALTER TABLE server_labels ADD CONSTRAINT fk_servers_labels
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;

-- SET NULL is impossible here: it would have to null `game`, which is part of the
-- primary key, so MySQL rejects the constraint. Deleting a server now requires
-- clearing guilds.server_id first.
ALTER TABLE guilds ADD KEY fk_guilds_server (server_id, game), ADD CONSTRAINT fk_guilds_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE channel_servers ADD KEY fk_channel_servers_server (server_id, game),
  ADD CONSTRAINT fk_channel_servers_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE job_books ADD KEY fk_job_books_server (server_id, game),
  ADD CONSTRAINT fk_job_books_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE alignment_books ADD KEY fk_alignment_books_server (server_id, game),
  ADD CONSTRAINT fk_alignment_books_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;


-- -----------------------------------------------------------------------------
-- 2. M1-B — twitter_accounts keyed by (id, game)
--
-- An account belongs to one game (Q7); the composite key exists so the webhook
-- foreign key carries the game, making a cross-game follow impossible.
-- -----------------------------------------------------------------------------

ALTER TABLE webhook_twitters DROP FOREIGN KEY fk_webhook_twitters_twitter_account;
ALTER TABLE webhook_twitters DROP INDEX fk_webhook_twitters_twitter_account;

ALTER TABLE twitter_accounts DROP PRIMARY KEY, ADD PRIMARY KEY (id, game);

ALTER TABLE webhook_twitters ADD KEY fk_webhook_twitters_twitter_account (twitter_id, game),
  ADD CONSTRAINT fk_webhook_twitters_twitter_account
  FOREIGN KEY (twitter_id, game) REFERENCES twitter_accounts (id, game)
  ON DELETE CASCADE ON UPDATE CASCADE;


-- -----------------------------------------------------------------------------
-- 3. M4 — almanaxes keyed by (month, day, game)
--
-- Dofus Touch has its own almanax, with different effects on the same day, so the
-- date alone does not identify a row. Nothing references almanaxes, so this is
-- self-contained.
-- -----------------------------------------------------------------------------

ALTER TABLE almanaxes
  ADD COLUMN game INT NOT NULL DEFAULT 1 AFTER day,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (month, day, game);

-- Existing rows are Dofus; drop the default so new rows must state their game.
ALTER TABLE almanaxes ALTER COLUMN game DROP DEFAULT;


-- -----------------------------------------------------------------------------
-- 4. M2 — emoji snowflakes per application
--
-- An application emoji only renders for the application that owns it, and there
-- is one application per game and per environment.
-- -----------------------------------------------------------------------------

CREATE TABLE emoji_snowflakes (
  emoji_id   VARCHAR(191) NOT NULL,
  emoji_type VARCHAR(191) NOT NULL,
  game       INT          NOT NULL,
  production BOOLEAN      NOT NULL,
  snowflake  VARCHAR(250) NOT NULL,
  PRIMARY KEY (emoji_id, emoji_type, game, production),
  CONSTRAINT fk_emoji_snowflakes_emoji FOREIGN KEY (emoji_id, emoji_type)
    REFERENCES emojis (id, type) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Today's snowflakes belong to the Dofus applications (game 1).
-- Unicode emojis have no snowflake and get no row: they fall back on `name`.
INSERT INTO emoji_snowflakes (emoji_id, emoji_type, game, production, snowflake)
  SELECT id, type, 1, TRUE,  snowflake     FROM emojis WHERE snowflake     IS NOT NULL AND snowflake     <> ''
  UNION ALL
  SELECT id, type, 1, FALSE, snowflake_dev FROM emojis WHERE snowflake_dev IS NOT NULL AND snowflake_dev <> '';


-- -----------------------------------------------------------------------------
-- 5. M3 — drop the old emoji columns
--
-- Only safe because every pod is stopped and the next deploy carries EMO-2 and
-- EMO-3. Skip this section if the emoji code is not ready to be deployed.
-- -----------------------------------------------------------------------------

ALTER TABLE emojis DROP COLUMN snowflake, DROP COLUMN snowflake_dev;


-- -----------------------------------------------------------------------------
-- 6. POST-CHECKS — every row below must be 0.
-- -----------------------------------------------------------------------------

-- Every non-unicode emoji kept a Dofus snowflake in both environments.
SELECT 'emoji snowflakes lost' AS check_name, COUNT(*) AS bad_rows
  FROM emojis e
  LEFT JOIN emoji_snowflakes s
    ON s.emoji_id = e.id AND s.emoji_type = e.type AND s.game = 1 AND s.production = TRUE
  WHERE s.snowflake IS NULL AND e.name = '';

-- Server labels inherited their server's game.
SELECT 'server_labels game mismatch', COUNT(*)
  FROM server_labels sl LEFT JOIN servers s ON s.id = sl.server_id AND s.game = sl.game
  WHERE s.id IS NULL;

-- Every almanax row is tagged Dofus.
SELECT 'almanaxes not tagged', COUNT(*) FROM almanaxes WHERE game <> 1;

-- Then confirm by hand:
--   SHOW CREATE TABLE servers;          -- PRIMARY KEY (id, game)
--   SHOW CREATE TABLE server_labels;    -- PRIMARY KEY (server_id, game, locale)
--   SHOW CREATE TABLE twitter_accounts; -- PRIMARY KEY (id, game)
--   SHOW CREATE TABLE almanaxes;        -- PRIMARY KEY (month, day, game)
--   SHOW CREATE TABLE emojis;           -- no snowflake / snowflake_dev
-- and keep a fresh structure export next to the pre-migration one.
