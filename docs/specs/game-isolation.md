# Spec — Game isolation across KaellyBot services

| | |
| --- | --- |
| Status | Draft |
| Date | 2026-09-17 |
| Scope | kaelly-amqp, kaelly-discord, Kaelly-books, Kaelly-competition, kaelly-configurator, Kaelly-encyclopedia, Kaelly-notifier, Kaelly-metrics, kaelly-rss, kaelly-twitter (Kaelly-registrar / Kaelly-commands: KaellyTouch prerequisites only, §4.10) |
| Out of scope | Building kaellytouch-discord itself, adding Dofus Touch data sources, legacy KaellyTOUCH data migration, kaelly-underwatch |

## 1. Goal

Before a second bot (`kaellytouch-discord`, `game = DOFUS_TOUCH = 2`) is plugged onto the same RabbitMQ and MySQL, every service must handle the game explicitly, so that:

1. **Nothing changes for kaelly-discord** (`game = DOFUS_GAME = 1`): same commands, same answers, same queues, same data.
2. **Every AMQP message** (request, reply, news) carries the right game.
3. **Every SQL query** that reads or writes per-game data filters on the game.
4. **Every external API call** (dofusdude, Discord) uses the source that matches the game, or the request is refused explicitly.
5. A request for a game a service does not support yet gets a `FAILED` reply. It must never get another game's data.

### Non-goals

- Serving real Dofus Touch data: encyclopedia sources, almanax, KTArena maps.
- Dofus Retro.
- Routing keys per game (see §9).

## 2. Background

`RabbitMQMessage.game` (field 4) is a proto3 enum:

```proto
enum Game { ANY_GAME = 0; DOFUS_GAME = 1; DOFUS_TOUCH = 2; DOFUS_RETRO = 3; }
```

`ANY_GAME` is the zero value, so **a message where the game was never set looks exactly like one tagged `ANY_GAME`**. Today most replies are sent without a game, and nothing fails because only one game exists.

### 2.1 Current state (audited 2026-09-17)

| Service | AMQP role | Game on outgoing messages | Game in SQL / API |
| --- | --- | --- | --- |
| kaelly-amqp | library | n/a | n/a |
| kaelly-discord | requests + guild news | ✅ all, from `constants.GetGame()` (hard-coded) | ⚠️ twitter accounts and guilds not filtered |
| Kaelly-books | replies | ❌ none | ✅ queries filtered; ⚠️ FKs ignore game |
| Kaelly-competition | replies | ❌ none | ❌ game dropped (no DB) |
| kaelly-configurator | replies | ❌ none | ⚠️ writes OK; guild preloads + twitter lookup not filtered |
| Kaelly-encyclopedia | replies + news | ❌ replies none; news hard-coded `DOFUS_GAME` | ❌ `dofus3` hard-coded, caches/sets not keyed by game |
| Kaelly-notifier | consumer | n/a | ⚠️ twitter by ID only, guild news ignores game, single Discord token |
| Kaelly-metrics | consumer | n/a | ✅ tags points with game |
| kaelly-rss | news | ✅ from `feed_sources.game` | ✅ |
| kaelly-twitter | news | ✅ from `twitter_accounts.game` | ✅ |
| Kaelly-registrar | none (Discord API) | n/a | no shared data; Touch prerequisite only (§4.10) |
| Kaelly-commands | none (library) | n/a | no shared data; Touch prerequisite only (§4.10) |

### 2.2 kaelly-amqp versions

| Version | Services |
| --- | --- |
| v1.0.0 | books, competition, configurator, rss, twitter, metrics |
| v1.0.4 | discord, registrar |
| v1.0.5 | encyclopedia, notifier |

Wire compatibility has been checked:

- v1.0.0 → v1.0.5 renumbers fields only in `EncyclopediaAlmanaxAnswer`, `EncyclopediaItemAnswer` and `NewsSetMessage`, and removes `Portal*`.
- v1.0.4 → v1.0.5 only changes `NewsSetMessage`.
- None of the v1.0.0 services uses those messages. Upgrading them is safe; each one still needs to build and pass its tests after the upgrade.

## 3. Contract rules

These rules apply to every service. Section 4 lists what each project has to change to meet them.

| ID | Rule |
| --- | --- |
| **R1** | Every published message has `game ≠ ANY_GAME`. |
| **R2** | A reply (success **or** failure) has `game = request.game`. Replies are built with the shared helper (§4.1), never with a bare literal. |
| **R3** | A news message has the game of the data it describes: the DB row, or the source that was polled. The game is never hard-coded in a mapper; it is passed in as a parameter. |
| **R4** | A consumer validates `request.game` before any other work:<br>• `ANY_GAME`: refused by the kaelly-amqp guards (AMQP-2/3), with an `error` log. Such a message is never published, and never reaches a consumer.<br>• A game the service does not support: reply `FAILED` with the request's game. |
| **R5** | Every SQL read or write on a table that has a `game` column filters or sets the game, including preloads, joins, deletes and cascades. Tables without a `game` column are shared across games by design (listed in §5). |
| **R6** | Every external call that depends on the game (dofusdude game path, Discord token or application) chooses its target from the game. When there is no target for that game, the call is not made and the error is explicit. |
| **R7** | In-memory stores and caches holding per-game data are keyed by game. |
| **R8** | Each bot uses its own AMQP client ID, so each has its own `<clientID>.answers` queue. The current name `KaellyBot-<shard>` must stay unchanged, because these queues are durable. |
| **R9** | Logs for request handling include the game (`constants.LogGame`). |
| **R10** | Reference data can differ per game: `jobs`, `cities`, `orders`, `servers`, their `*_labels`, feeds, twitter accounts, almanax news. Every lookup of reference data (DB query, preload, in-memory store, foreign key) is scoped to one game. `jobs`, `cities`, `orders`, `servers` and `twitter_accounts` are identified by **`(id, game)`**: the same ID may exist in several games with different data. |
| **R11** | **One Discord application per game** (plus one dev application per game). Every Discord resource is resolved from the game of the message or data being handled, never from the service's own identity:<br>• bot token and session<br>• application/client ID<br>• application emojis<br>• commands<br>• news channels (the reporting channel is shared, but each report is sent by its game's bot)<br>• branding (name, avatar, footer)<br>A service handling several games (e.g. the notifier) picks these per message. A single-game service (e.g. kaelly-discord) picks them from its configured `GAME`. |

## 4. Changes per project

Each item has an ID so it can be referenced in commits and PRs.

### 4.1 kaelly-amqp — release v1.0.6

- **AMQP-1** — Add helpers in a new file (not in the generated `rabbitmq.pb.go`):

  ```go
  // NewReply builds a reply carrying the request's game and language.
  func NewReply(request *RabbitMQMessage, t RabbitMQMessage_Type, status RabbitMQMessage_Status) *RabbitMQMessage
  func NewFailedReply(request *RabbitMQMessage, t RabbitMQMessage_Type) *RabbitMQMessage
  // IsGameSet reports whether game != ANY_GAME.
  func (x *RabbitMQMessage) IsGameSet() bool
  ```

- **AMQP-2** — Add a game guard in `publish()` (`broker.go`, before `proto.Marshal`):
  - When `msg.Game == ANY_GAME`: log at `error` (type, exchange, routing key, correlation ID), **do not publish**, and return `ErrGameNotSet`.
  - This is the default. There is no opt-out.
- **AMQP-3** — Consumer-side guard, on by default:
  - Before calling the consumer, a message with `ANY_GAME` is logged at `error` (type, correlation ID, reply-to) and acked without being passed on.
  - New option `WithRejectedHandler(func(ctx Context, msg *RabbitMQMessage, err error))`, called for every message the guard refuses. This lets a service react, e.g. kaelly-discord answering the user (DISC-9).
  - The library cannot build a typed `FAILED` answer itself. A backend receiving an `ANY_GAME` request only logs it, and the requester relies on its own timeout (DISC-9).
  - Service-level R4 checks remain for unsupported games.
- **AMQP-4** — README: document R1–R11, and that the client ID determines the reply queue name (`broker.go:145`, `:372`).
- **AMQP-5** — Tests for the helpers and for both guards (publish and consume), using the existing `Mock` where possible.
- **Acceptance:** tag v1.0.6. No change to `rabbitmq.proto` field numbers.

### 4.2 kaelly-discord

- **DISC-1** — Make the game configurable:
  - Add a viper key `GAME`, default `DOFUS_GAME`, parsed with `amqp.Game_value`.
  - `constants.GetGame()` (`models/constants/games.go:15`) returns Name and Icon from a per-game table.
  - Startup fails on `ANY_GAME` or an unknown value.
- **DISC-2** — Make the client ID configurable:
  - Add a viper key `RABBITMQ_CLIENT_NAME`, default `KaellyBot`.
  - `GetRabbitMQClientID()` (`models/constants/broker.go:22`) uses it instead of `constants.Name`.
  - Result: the default queue stays `KaellyBot-<shard>.answers`, unchanged.
- **DISC-3** — Filter guild queries by game (`repositories/guilds/guilds.go`):
  - Add `Game` to `entities.Guild` (`models/entities/guilds.go`) as part of the primary key.
  - `Exists(guildID)` → `Exists(guildID, game)`. Used by `services/discord/discord.go:101,131`. Without this fix, a guild already registered by the other bot suppresses the create/delete news, and the configurator never creates this bot's guild row.
  - `GetServer(guildID, channelID)`: add `guilds.game = ?` to the `WHERE`, and `AND channel_servers.game = guilds.game` to the `JOIN`.
- **DISC-8 (required)** — Servers keyed by `(id, game)` (`models/entities/servers.go`):
  - `Server.Game` becomes part of the primary key.
  - `ServerLabel` gets a `Game` primary-key field.
  - `Server.Labels` becomes `foreignKey:ServerID,Game;references:ID,Game`.
  - `GetServers` already filters on game (`repositories/servers/servers.go:17`), so the in-memory store in `services/servers` stays keyed by ID: it only ever holds one game.
- **DISC-9 (required)** — The user always gets an answer (`utils/requests/requests.go`):
  - **Request refused at publish** (`ErrGameNotSet` or any broker error): `Request` returns the error, the command panics, and `panics.HandlePanic` edits the reply with the `panic` message. This already works; add a test.
  - **Reply refused by the consumer guard:** register `WithRejectedHandler` (AMQP-3). The handler looks up `manager.requests[ctx.CorrelationID]`, removes it, and edits the interaction with the `panic` message, as `HandlePanic` does.
  - **Reply never arrives** (backend down, message lost, backend refused an `ANY_GAME` request):
    - Add a request timeout, configurable, default 60 s and well below Discord's 15-minute interaction token lifetime.
    - On expiry, remove the request and answer the user with the `panic` message (or a dedicated `timeout` i18n key).
    - Today the entry stays in the map forever and the user sees "thinking…" indefinitely.
  - **Concurrency:** `manager.requests` is read and written by commands and by the answer consumer in different goroutines, without a lock. Protect it with a `sync.Mutex`.
  - **Late replies:** a reply arriving after the timeout is ignored (not found), as today.
- **DISC-4** — Twitter accounts keyed by `(id, game)`:
  - `entities.TwitterAccount` (`models/entities/twitters.go`): `Game` becomes part of the primary key.
  - `repositories/twitters/twitters.go:15`: add `Where("game = ?", constants.GetGame().AMQPGame)`.
- **DISC-5** — Confirm that `emojis`, `weapons` and `characteristics` are game-agnostic (§5). No change if confirmed.
- **DISC-6** — Upgrade to kaelly-amqp v1.0.6.
- **DISC-7** — Test: iterate over every `models/mappers.Map*Request` plus `MapGuildCreateNews` and `MapGuildDeleteNews`, and assert `IsGameSet()`.
- **Acceptance:** with default config, the published messages and the queue names are byte-identical to today, except for the new guards.

### 4.3 Kaelly-books

- **BOOK-1** — Replies:
  - `utils/replies/replies.go`: `FailedAnswer` takes the request and uses `amqp.NewFailedReply`.
  - Every `Map*Answer` in `models/mappers/{alignments,jobs}.go` sets `Game` from the request.
- **BOOK-2** — Validation: in `services/books/books.go` `consume`, reject `ANY_GAME` (R4) and any game other than `DOFUS_GAME` / `DOFUS_TOUCH`. Books are game-generic, so Touch is supported as soon as the reference data (jobs, cities, orders) exists for game 2.
- **BOOK-3 (code alignment only)** — Production already has `fk_job_books_job (job_id, game)` and `fk_alignment_books_city / _order (…, game)` (§5.1). Only the gorm tags are stale: `models/entities/books.go:11,21-22` say `foreignKey:JobID;references:ID`. Change them to `foreignKey:JobID,Game;references:ID,Game` (and the same for `City` and `Order`), so the code documents the real schema. No migration.
- **BOOK-6 (required)** — Servers:
  - `entities.Server` (`models/entities/servers.go`) gets `Game` as part of its primary key.
  - The `Server` associations of `JobBook` and `AlignmentBook` (`books.go:12,24`) become `foreignKey:ServerID,Game;references:ID,Game`, matching M1-A (§5.3).
  - The book queries already filter on `server_id` **and** `game` (`repositories/{jobs,alignments}`); no change is needed there.
- **BOOK-4** — Log the game (R9). Also fix the copy-pasted log line in `services/alignments/user.go:21`.
- **BOOK-5** — Upgrade to v1.0.6, which also brings the v1.0.0 → v1.0.6 upgrade (§2.2).
- **Acceptance:** replies carry the request's game. The same user/server/job with game 1 and game 2 gives two independent books.

### 4.4 Kaelly-competition

- **COMP-1** — Replies: same pattern as BOOK-1 (`models/mappers/maps.go:12`, `utils/replies/replies.go:22`).
- **COMP-2** — `services/competitions/competitions.go:100`: pass `message.Game` down to `maps.Service.GetMapRequest`, which gets a new `game` parameter.
- **COMP-3** — Supported games: `DOFUS_GAME` only for now. `DOFUS_TOUCH` gets a `FAILED` reply. KTArena maps are Dofus-only (`models/constants/ktarena.go`).
  - kaellytouch-discord shows `/map` as "not supported yet" (Q2). This reply is the backend safety net.
- **COMP-4** — Upgrade to v1.0.6.

### 4.5 kaelly-configurator

- **CONF-1** — Replies: same pattern as BOOK-1 (`utils/replies/replies.go`, `services/configurators/set.go:12,27,46,56`, `models/mappers/guilds.go:19`).
- **CONF-2** — Guild read (`repositories/guilds/guilds.go:19-22`): filter every preload by game:

  ```go
  Preload("ChannelServers", "game = ?", game).
  Preload("AlmanaxWebhooks", "game = ?", game).
  Preload("FeedWebhooks", "game = ?", game).
  Preload("TwitterWebhooks", "game = ?", game).
  Preload("TwitterWebhooks.TwitterAccount")
  ```

  Remove the `.Limit(1)` that follows `Find` (it has no effect).
- **CONF-3** — Twitter webhooks:
  - Add `game` to `repositories/twitter` `Get` (`twitter.go:15`) and `GetTwitterWebhook`, and to `services/channels` (`channels.go:32`) and `services/configurators/twitter.go:9`.
  - **Risk if missing:** with the same guild, channel and Twitter ID configured for both games, the lookup may return the other game's row. The configurator then deletes that row and answers `RemoveWebhook` with its ID, so the bot deletes **the other bot's** Discord follow webhook.
  - **Keys:**
    - `entities.TwitterAccount` (`models/entities/twitter.go`): `Game` becomes part of the primary key.
    - `WebhookTwitter.TwitterAccount` (`webhooks.go:30`) becomes `foreignKey:TwitterID,Game;references:ID,Game`.
    - The database then rejects a webhook pointing at another game's account (M1).
  - Summary of webhook tables:
    - `webhook_almanaxes` / `webhook_feeds`: `Get`, `Save` and `Delete` already use the game. Only the guild preloads (CONF-2) remain.
    - kaelly-discord chooses which news channel to follow from its own game-filtered data (feed sources, almanax news, and Twitter accounts once DISC-4 is done).
- **CONF-4 (code alignment only)** — Guild deletion never crosses games in production:
  - `channel_servers → guilds` is already `(guild_id, game)` with CASCADE.
  - The webhook tables have no FK to `guilds` (§5.3).
  - Change `ChannelServer.Guild` (`chanservers.go:10`) and `Guild.ChannelServers` (`guilds.go:11`) to `foreignKey:GuildID,Game;references:ID,Game`, so the code documents the real schema. Remove the `constraint:` part from the three webhook associations (`guilds.go:12-14`), since production has no such FK.
  - No migration. Acceptance: deleting guild `(id, 2)` leaves every game-1 row intact (repository test).
- **CONF-7 (required)** — Servers keyed by `(id, game)`:
  - `entities.Server` (`models/entities/servers.go`) gets `Game` as part of its primary key.
  - `Guild.Server` (`guilds.go:10`) becomes `foreignKey:ServerID,Game;references:ID,Game`.
    - MySQL cannot keep `OnDelete:SET NULL` on this key: SET NULL would also null `game`, which is part of the primary key, so MySQL rejects the constraint.
    - Use `OnDelete:RESTRICT`. Deleting a server then requires clearing `guilds.server_id` first, in the same migration or script.
  - `ChannelServer.Server` (`chanservers.go:11`) becomes `foreignKey:ServerID,Game;references:ID,Game`.
- **CONF-5** — Validation: reject `ANY_GAME` in `consumeRequests` and `guildNews` (R4).
- **CONF-6** — Upgrade to v1.0.6.
- **Acceptance:** with a guild configured for both games:
  - `CONFIGURATION_GET` for game 1 returns only game-1 rows.
  - Deleting guild (id, 2) leaves every game-1 row intact.

### 4.6 Kaelly-encyclopedia

- **ENC-1** — Replies:
  - `replyWithFailedAnswer` (`services/encyclopedias/encyclopedias.go:107`) takes the request.
  - Every mapper in `models/mappers/{lists,items,almanax}.go` sets `Game` from the request.
- **ENC-2** — Validation in `consume` (`encyclopedias.go:83`): supported games are `DOFUS_GAME` only. Any other game gets a `FAILED` reply carrying that game, and no dofusdude call is made.
  - kaellytouch-discord shows `/item`, `/set` and `/almanax` as "not supported yet" (Q2). This reply is the backend safety net.
- **ENC-3** — Game → source mapping:
  - Replace `constants.DofusDudeGame` with `func DofusDudeGame(game amqp.Game) (string, bool)`, where `DOFUS_GAME` maps to `"dofus3"`.
  - Every `sources.Service` method (`services/sources/types.go`, `dofusdude.go`) takes `game`.
  - Almanax calls (`dofusdude.go:462, 487, 535`) currently take no game. They must refuse anything other than `DOFUS_GAME`.
- **ENC-4** — Caches: add the game to `buildListKey` / `buildItemKey` (`services/sources/stores.go:40-46`). Existing Redis entries without a game segment simply expire. Changing the key format means cache misses right after deployment; this is expected.
- **ENC-5** — Sets:
  - `repositories/sets/sets.go` `GetSets`, the `Sync` update (`:30`) and the delete (`:38`) filter by game.
  - Fix the delete column: `dofus_dude_id` does not exist; it must be `id`.
  - `services/sets/sets.go:61` store: key it by `(game, id)`.
  - `GetSetByDofusDude(id)`: add a `game` parameter.
- **ENC-6** — News:
  - `MapAlmanaxNews`, `MapGameNews` and `MapSetNews` (`models/mappers/news.go`) take `game`.
  - `GameEventHandler` becomes `func(game amqp.Game, version string)`.
  - `checkGameVersion` (`services/sources/games.go:18`), the daily almanax, the set sync and the almanax reconcile are driven by a list of supported games, which today is `[DOFUS_GAME]`.
- **ENC-7** — `entities.Almanax` has no `game` column. Document it as Dofus-only. Adding a game column is deferred until Touch almanax exists.
- **ENC-8** — Log the game (R9).
- **Acceptance:**
  - For game 1, replies and news are identical to today's except that `game` is now set.
  - A game-2 request gets `FAILED` with game 2, and no HTTP call is made.

### 4.7 Kaelly-notifier

The notifier posts each news message **as the bot of the news' game**, into **that game's channel**. One instance handles both games with two Discord tokens.

Each news channel belongs to one bot. Only the author of a message can crosspost it (`ChannelMessageCrosspost`), and Discord servers follow the channel of the bot matching their game (see CONF-3). So the token must always match the game of the channel it posts to.

- **NOTI-1** — Configuration (`models/constants/config.go`, chart `values.yaml`, CI):

  | Key | Game | Required | Note |
  | --- | --- | --- | --- |
  | `DISCORD_TOKEN` | DOFUS_GAME | yes | existing, unchanged |
  | `DISCORD_TOKEN_DOFUS_TOUCH` | DOFUS_TOUCH | no | new |
  | `REPORTING_CHANNEL_ID` | all games | yes | existing, unchanged; one channel shared by every bot |

  - A game with no token is **disabled**: its news is logged at `warn` and dropped. It is never posted with another game's token.
  - Startup logs which games are enabled.
- **NOTI-2** — Discord service (`services/discord/`):
  - `Impl` holds `sessions map[amqp.Game]*discordgo.Session`, built from NOTI-1.
  - `AnnounceMessage(correlationID string, game amqp.Game, newsChannelID string, msg)` and `SendMessage(correlationID string, game amqp.Game, channelID, content string)` pick the session for `game`. When no session exists, they log and return.
  - Send and crosspost use **the same** session.
  - `Shutdown` closes every session.
- **NOTI-3** — Channel resolution per news type. Every lookup includes the game:

  | Type | Channel source | Change |
  | --- | --- | --- |
  | NEWS_ALMANAX | `almanax_news(locale, game)` | ✅ already |
  | NEWS_RSS | `feed_sources(type, locale, game)` | ✅ already |
  | NEWS_TWITTER | `twitter_accounts(id, game)` | ❌ → `GetTwitterAccount(id, game)` (`services/news/news.go:61`); entity primary key becomes `(id, game)` |
  | NEWS_SET, NEWS_GAME | shared reporting channel | ❌ → sent with the session of `message.Game`; text names the game |
  | NEWS_GUILD | shared reporting channel | ❌ → sent with the session of `message.Game`; text names the bot/game (`models/mappers/guilds.go`) |

  - `services/news/news.go` loads `almanax_news`, `feed_sources` and `twitter_accounts` for **all** games at startup (no game filter), since the notifier serves every game. Lookups always filter on game.
- **NOTI-4** — Content per game:
  - Branding (`constants.ExternalName`, `AvatarURL`, footer in `utils/discord/discord.go`) is chosen from the game.
  - Emojis: see NOTI-6.
- **NOTI-5** — Validation: `ANY_GAME` news is dropped by the AMQP-3 guard (error log). SET and GAME text must no longer fall back to "Ankama".
- **NOTI-6** — Emojis are per application: see §4.11 (EMO-3).
- **NOTI-7** — Deployment:
  - Add `secrets.DISCORD_TOKEN_DOFUS_TOUCH` to `.github/workflows/ci.yml` (optional, empty allowed).
  - Both bots must have Send Messages / Manage Messages rights in their own news channels.
  - **Both bots must be members of the reporting channel's guild**, with Send Messages rights.
- **Acceptance:**
  - With only today's variables set, behaviour is byte-identical to today.
  - With both tokens set:
    - a game-1 almanax is posted and crossposted by KaellyBot in the game-1 channel;
    - a game-2 almanax is posted and crossposted by KaellyTouch in the game-2 channel;
    - a game-2 tweet whose account row is game 1 is dropped.
  - With only `DISCORD_TOKEN` set, game-2 news is logged and not posted.
  - Tests use a Discord service mock that records `(game, channelID)` for each call.

### 4.8 Kaelly-metrics

- **METR-1** — No functional change. `ANY_GAME` requests are dropped by the AMQP-3 guard before reaching metrics; add a counter for them if the library exposes a hook.
- **METR-2** — Upgrade to v1.0.6.
- Note: the `shard` tag is taken from `ReplyTo`. After DISC-2, a second bot shows up with its own prefix.

### 4.9 kaelly-rss / kaelly-twitter

- **RSS-1 / TWIT-1** — At load time, skip rows with `game = 0` and log at `error` (R1). AMQP-2 would refuse to publish them anyway.
- **TWIT-4** — Twitter accounts keyed by `(id, game)`:
  - `entities.TwitterAccount` (`models/entities/twitter.go`): `Game` becomes part of the primary key. `Save` (`repositories/twitteraccounts/twitteraccounts.go:19`) then updates only the `(id, game)` row.
  - The same account can now appear on several rows (one per game). `DispatchNewTweets` (`services/twitter/twitter.go:30`) groups rows by `id`:
    - it fetches tweets **once** per account, to avoid doubling Twitter calls and rate-limit hits;
    - then, for each row, it publishes the tweets newer than **that row's** `last_update`, with that row's `game` and `locale`, and saves that row.
  - The correlation ID must stay unique per message: `tweet.ID` becomes `tweet.ID + "-" + game` (`twitter.go:124`).
- **RSS-2** — Unrelated fixes found during the audit:
  - `services/feeds/feeds.go:75`: log `errPublish`.
  - `services/feeds/feeds.go:85`: use `feedItem.PublishedParsed`, with a nil guard.
- **TWIT-2** — Unrelated fix: `services/twitter/twitter.go:74`: log `errPublish`.
- **RSS-3 / TWIT-3** — Upgrade to v1.0.6.

### 4.10 Kaelly-commands / Kaelly-registrar — not required for isolation

These two projects use neither AMQP nor the shared database: they only register slash commands on one Discord application. **Nothing here is needed to isolate the games**, and nothing changes for KaellyBot. The items below are prerequisites for **launching kaellytouch-discord**, listed so they are not forgotten.

- **CMD-1** — `GetCommands()` (`commands.go:5`) → `GetCommands(game amqp.Game)`. The game name inserted in descriptions comes from the game instead of the hard-coded `GetGame()` (`models/constants/games.go:4`). Release a new version.
- **DISC-TOUCH-1** — kaelly-discord reads the command IDs (`ABOUT_ID`, `ALIGN_ID`, `ALMANAX_ID`, `CONFIG_ID`, `HELP_ID`, `ITEM_ID`, `JOB_ID`, `MAP_ID`, `SET_ID`; `models/constants/config.go:33-56`) from its configuration. These IDs belong to one Discord application, so the Touch deployment must use the IDs returned by the Touch registrar. Configuration only; no code change.
- **REG-1** — Registrar:
  - Add a `GAME` env var, default `DOFUS_GAME`, passed to `GetCommands`.
  - One deployment (values file) per bot, each with its own `CLIENT_ID` / `TOKEN`.
- **Acceptance:** with defaults, the registered command payload is identical to today's.

### 4.11 Emojis (kaelly-discord, Kaelly-notifier)

Emojis are **application emojis**: a snowflake only renders for the bot application that owns it. With one application per game (R11), emoji snowflakes are **per game** (and per prod/dev environment).

Example: the notifier receives a `DOFUS_TOUCH` almanax. It posts with the Touch token **and** renders the Touch snowflakes, even though the same instance also posts Dofus news with KaellyBot's token and snowflakes.

Today:

- `emojis(id, type, discord_name, name, snowflake, snowflake_dev)` stores one application per environment.
- It is read by kaelly-discord (`repositories/emojis/emojis.go:14`, all types) and by Kaelly-notifier (`repositories/emojis/emojis.go:14`, types item and misc). Both pick `snowflake_dev` when `PRODUCTION=false`.

- **EMO-1** — Schema (migration M2, §5.4):
  - `emojis` keeps the shared metadata: `id`, `type`, `discord_name`, `name`.
  - New table `emoji_snowflakes(emoji_id, emoji_type, game, production, snowflake)`:
    - primary key `(emoji_id, emoji_type, game, production)`;
    - FK `(emoji_id, emoji_type) → emojis(id, type)` with `ON DELETE CASCADE`.
  - M2 copies the current `snowflake` into `(game=1, production=1)` and `snowflake_dev` into `(game=1, production=0)`.
  - `emojis.snowflake` / `snowflake_dev` stay until every reader has moved, then are dropped (M3).
- **EMO-2 (kaelly-discord)** — `GetEmojis()` becomes `GetEmojis(game, production)`:

  ```sql
  SELECT e.id, e.type, e.name, e.discord_name, s.snowflake
  FROM emojis e
  LEFT JOIN emoji_snowflakes s
    ON s.emoji_id = e.id AND s.emoji_type = e.type AND s.game = ? AND s.production = ?
  ```

  The bot's game comes from `constants.GetGame()`. `entities.Emoji` keeps its `Snowflake` field, filled from the join.
- **EMO-3 (Kaelly-notifier)**:
  - Load snowflakes for **every enabled game** (NOTI-1).
  - The emoji store (`services/emojis/emojis.go`) is keyed by `game → type → id`.
  - `GetMiscStringEmoji` / `GetItemTypeStringEmoji` take the game. Mappers (e.g. `mappers.MapAlmanax`) pass `message.Game`, so a game-2 almanax only contains KaellyTouch emojis.
- **EMO-4 (fallback, both services)** — When an emoji has no snowflake for the game:
  - render its unicode `name`, or nothing if `name` is empty;
  - log once at `warn`.
  - Never render another application's snowflake. Today `mapEmojiString` (notifier `services/emojis/emojis.go`) checks `emoji.ID`, not the snowflake; it must check the snowflake.
- **EMO-5** — Filling Touch snowflakes:
  - Upload the emojis to the KaellyTouch applications (prod and dev).
  - Insert rows `(emoji_id, emoji_type, 2, 1|0, snowflake)`.
  - Restart kaelly-discord (Touch) and the notifier.
- **Acceptance:**
  - After M2 + EMO-2/3, KaellyBot renders exactly the same emojis as today, in both prod and dev.
  - A game-2 message never contains a game-1 snowflake. Test: same emoji ID with different snowflakes per game.

## 5. SQL reference

**Tables with a `game` column.** Every query on these must filter or set the game (R5):

| Table | Game part of PK? | Readers / writers |
| --- | --- | --- |
| guilds | yes | discord (DISC-3), configurator |
| channel_servers | yes | discord (DISC-3), configurator (CONF-2) |
| webhook_almanaxes, webhook_feeds, webhook_twitters | yes | configurator (CONF-2/3) |
| alignment_books, job_books | yes | books |
| jobs, cities, orders | yes (same ID may exist per game) | discord (filtered ✅), books (FK `(…_id, game)` in production ✅; BOOK-3 aligns the tags) |
| job_labels, city_labels, order_labels | yes (FK `(id, game)` ✅) | discord |
| servers | **no → must become `(id, game)`** | discord (filtered ✅, DISC-8), books (BOOK-6), configurator (CONF-7) |
| server_labels | **no → must gain `game`** | discord (DISC-8) |
| feed_sources | yes | rss, notifier, discord |
| twitter_accounts | **no → must become `(id, game)`** | twitter (TWIT-4), notifier (NOTI-3), discord (DISC-4), configurator (CONF-3) |
| almanax_news | yes | notifier, discord |
| sets | yes | encyclopedia (ENC-5) |
| game_versions | yes (id = game) | encyclopedia |

**Tables without a `game` column.** These are shared by design; confirm or change:

- `emojis`: metadata only; the **snowflakes are per game/application**, in `emoji_snowflakes` (§4.11, M2)
- `weapon_area_effects`, `characteristics`
- `feed_types`
- `weapon_exceptions`, `equipment_types`
- `almanaxes` (Dofus-only, see ENC-7)

### 5.1 Production schema (snapshot 2026-09-17)

Source: phpMyAdmin structure export of `kaellybot` (MySQL 8.4.3), 31 tables: [`kaellybot-schema-2026-09-17.sql`](kaellybot-schema-2026-09-17.sql). No service runs `AutoMigrate`, so **this snapshot, not the gorm tags, is the reference**. Keep the export next to the migration scripts as the rollback reference.

What the snapshot shows, compared with the code:

| Relation | Production | Status |
| --- | --- | --- |
| `job_books → jobs` | `fk_job_books_job (job_id, game)` | ✅ already per game (BOOK-3 only aligns the gorm tags) |
| `alignment_books → cities / orders` | `fk_alignment_books_city / _order (…, game)` | ✅ already per game |
| `job_labels`, `city_labels`, `order_labels` | primary key and FK on `(…_id, game)` | ✅ |
| `channel_servers → guilds` | `fk_channel_servers_guild (guild_id, game)` | ✅ already per game |
| `webhook_almanaxes / _feeds / _twitters → guilds` | **no FK** | ✅ no cascade at all, so no cross-game effect. Left as is (§5.3) |
| `servers` | PK `(id)`; referenced by `guilds`, `channel_servers`, `job_books`, `alignment_books`, `server_labels` by `server_id` only | ❌ M1-A |
| `server_labels` | PK `(locale, server_id)`, no `game` | ❌ M1-A |
| `twitter_accounts` | PK `(id)`; `webhook_twitters.fk_webhook_twitters_twitter_account (twitter_id)` | ❌ M1-B |
| `jobs`, `cities`, `servers`, `characteristics`, `weapon_area_effects` | FK `(id, emoji_type) → emojis (id, type)`, RESTRICT | ⚠️ every new job, city or server needs its `emojis` row first (§5.2) |
| `feed_sources`, `almanax_news`, `sets`, `game_versions` | game in PK | ✅ |
| `emojis` | PK `(id, type)`, `snowflake` + `snowflake_dev` | M2 |

MySQL 8.4 constraints that shape the migrations:

- **`restrict_fk_on_non_standard_key` is ON by default.** A foreign key must reference a full primary or unique key. So every FK to `servers(id)` / `twitter_accounts(id)` must be dropped **before** those primary keys change.
- **Each old FK has a supporting index with the same name** (e.g. `KEY fk_guilds_server (server_id)`). Drop that index too, otherwise re-creating the constraint under the same name fails with a duplicate key name.
- **`ON DELETE SET NULL` is not allowed** when a child FK column is `NOT NULL`. `guilds.fk_guilds_server` becomes `RESTRICT` (CONF-7).
- **DDL is not transactional.** Stop books, configurator, twitter and notifier while running M1. kaelly-discord only reads, so it can keep running.
  - **Accepted downtime:** a few minutes, since this is not a critical system.
  - During that window, `/job`, `/align` and `/config` answer with an error: the DISC-9 timeout, deployed in phase A.
  - News published meanwhile waits in the durable RabbitMQ queues and is posted when the notifier restarts.

### 5.2 Adding per-game reference data (e.g. Dofus Touch jobs)

kaelly-discord loads `jobs`, `cities`, `orders`, `servers` and `almanax_news` with `WHERE game = <bot game>` (`repositories/{jobs,cities,orders,servers,almanaxes}/*.go:17`), and label preloads join on `(id, game)`. Inserting game-2 rows **does not change** what KaellyBot shows.

Insertion order (the FKs require it):

1. **`emojis`:** the row `(id, emoji_type)` for the new job, city or server, if that ID does not exist yet. Then its **game-2 snowflakes** in `emoji_snowflakes` (after M2).
2. **`jobs` / `cities` / `orders`** with `game = 2` (the same ID as Dofus is allowed), then their `*_labels` with the same `(id, game)`. These tables are already keyed per game, so no migration is needed.
3. **`servers`:** only **after M1-A**, with `game = 2`, then `server_labels` with `game = 2`. Before M1-A, inserting a Touch server whose ID exists for Dofus fails on the primary key.
4. **`feed_sources`, `almanax_news`:** insert with `game = 2`.
5. **`twitter_accounts`:** only **after M1-B**. The same Twitter ID may be inserted for game 2, with its own `news_channel_id` and `locale`, and with **`last_update = NOW()`**, otherwise the Touch bot republishes the whole history.
6. **Restart** the services that cache reference data at startup: kaelly-discord and Kaelly-notifier.

Check after inserting (must return 0 rows):

```sql
SELECT 'jobs without labels', j.id, j.game FROM jobs j
  LEFT JOIN job_labels l ON l.job_id = j.id AND l.game = j.game WHERE l.job_id IS NULL
UNION ALL SELECT 'cities without labels', c.id, c.game FROM cities c
  LEFT JOIN city_labels l ON l.city_id = c.id AND l.game = c.game WHERE l.city_id IS NULL
UNION ALL SELECT 'orders without labels', o.id, o.game FROM orders o
  LEFT JOIN order_labels l ON l.order_id = o.id AND l.game = o.game WHERE l.order_id IS NULL;
```

Tests (repository level, per service) must insert the **same ID for game 1 and game 2 with different labels** and check that each game only ever sees its own labels.

### 5.3 Migration M1 — servers and twitter accounts

Take a backup first (phpMyAdmin export, structure **and** data). Constraint and index names below are the real production names.

#### M1-0 — pre-checks (all must return 0)

```sql
SELECT COUNT(*) FROM servers WHERE game NOT IN (1, 2, 3);
SELECT COUNT(*) FROM guilds          x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game;
SELECT COUNT(*) FROM channel_servers x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game;
SELECT COUNT(*) FROM job_books       x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game;
SELECT COUNT(*) FROM alignment_books x JOIN servers s ON s.id = x.server_id WHERE s.game <> x.game;
SELECT COUNT(*) FROM webhook_twitters w JOIN twitter_accounts t ON t.id = w.twitter_id WHERE t.game <> w.game;
```

#### M1-A — `servers` / `server_labels` keyed by `(id, game)`

```sql
-- 1. Drop every FK (and its same-named index) that references servers(id)
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

-- 2. Re-key
ALTER TABLE servers DROP PRIMARY KEY, ADD PRIMARY KEY (id, game);
ALTER TABLE server_labels ADD COLUMN game INT NOT NULL DEFAULT 1 AFTER server_id;
UPDATE server_labels sl JOIN servers s ON s.id = sl.server_id SET sl.game = s.game;
ALTER TABLE server_labels DROP PRIMARY KEY, ADD PRIMARY KEY (server_id, game, locale);

-- 3. Recreate composite FKs
ALTER TABLE server_labels ADD CONSTRAINT fk_servers_labels
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE guilds ADD KEY fk_guilds_server (server_id, game), ADD CONSTRAINT fk_guilds_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE channel_servers ADD KEY fk_channel_servers_server (server_id, game), ADD CONSTRAINT fk_channel_servers_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE job_books ADD KEY fk_job_books_server (server_id, game), ADD CONSTRAINT fk_job_books_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE alignment_books ADD KEY fk_alignment_books_server (server_id, game), ADD CONSTRAINT fk_alignment_books_server
  FOREIGN KEY (server_id, game) REFERENCES servers (id, game) ON DELETE CASCADE ON UPDATE CASCADE;
```

Notes:

- `guilds.server_id` and `channel_servers.server_id` are nullable. With MySQL's default `MATCH SIMPLE`, a row whose `server_id` is NULL is not checked, so guilds without a default server stay valid.
- **`guilds.fk_guilds_server` changes from `SET NULL` to `RESTRICT`.** To delete a server, first run `UPDATE guilds SET server_id = NULL WHERE server_id = ? AND game = ?`.
- `servers.fk_server_emoji (id, emoji_type)` is unaffected.

#### M1-B — `twitter_accounts` keyed by `(id, game)`

```sql
ALTER TABLE webhook_twitters DROP FOREIGN KEY fk_webhook_twitters_twitter_account;
ALTER TABLE webhook_twitters DROP INDEX fk_webhook_twitters_twitter_account;

ALTER TABLE twitter_accounts DROP PRIMARY KEY, ADD PRIMARY KEY (id, game);

ALTER TABLE webhook_twitters ADD KEY fk_webhook_twitters_twitter_account (twitter_id, game),
  ADD CONSTRAINT fk_webhook_twitters_twitter_account
  FOREIGN KEY (twitter_id, game) REFERENCES twitter_accounts (id, game) ON DELETE CASCADE ON UPDATE CASCADE;
```

#### Not migrated — webhook → guild FKs

The webhook tables have no FK to `guilds`, and **none is added**:

- **No FK means no cascade**, so a guild delete for one game cannot touch another game's webhooks. Isolation already holds.
- **Adding `ON DELETE CASCADE` would change behaviour:**
  - Discord channel-follow webhooks keep delivering after the bot leaves a guild, but their rows would be deleted. After a rejoin, `/config get` would hide still-active follows, and re-enabling them would create duplicates.
  - The configurator saves webhooks without ensuring the guild row exists (`services/configurators/twitter.go:30`), so saves that succeed today could start failing.
- **Orphan webhook rows** (guild row missing) are a separate clean-up topic, not part of this spec.

#### M1 — after running

- Check that `SHOW CREATE TABLE` matches the target for every altered table, and keep the new export.
- **Transparent for the running services.** M1 changes keys and constraints only, and every row keeps its data. While each server and Twitter ID has a single row (game 1), code that ignores the game behaves exactly as before:
  - kaelly-discord already filters servers by game, and reads labels by `server_id` (still one set per server).
  - Books and configurator write `(server_id, game = 1)`, which the composite FKs accept.
  - kaelly-twitter saves by `id`, which still matches exactly one row.
  - The only difference: deleting a server referenced by a guild is refused (`RESTRICT`); no service deletes servers.
- **This stops holding once a second row shares an ID** (a game-2 server or Twitter account). The order is therefore **M1 → deploy the game-aware code → insert Touch data**.
- Then deploy DISC-4, DISC-8, BOOK-6, CONF-3, CONF-4, CONF-7, TWIT-4 and NOTI-3.
- Never update `servers.game` or `twitter_accounts.game`. Insert a new row instead.

### 5.4 Migration M2 — emoji snowflakes per application

```sql
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

INSERT INTO emoji_snowflakes (emoji_id, emoji_type, game, production, snowflake)
  SELECT id, type, 1, TRUE,  snowflake     FROM emojis WHERE snowflake     IS NOT NULL AND snowflake     <> ''
  UNION ALL
  SELECT id, type, 1, FALSE, snowflake_dev FROM emojis WHERE snowflake_dev IS NOT NULL AND snowflake_dev <> '';
```

- The column types match `emojis` (`id` / `type` `varchar(191)`, snowflakes `varchar(250)`, same collation).
- M2 only adds a table and copies data, so the current code keeps working.
- **M3** (`ALTER TABLE emojis DROP COLUMN snowflake, DROP COLUMN snowflake_dev`) runs only once EMO-2 and EMO-3 are deployed everywhere.
- Unicode emojis (empty snowflake) get no row and fall back to `name` through EMO-4. Check how kaelly-discord renders them today and keep the same output for game 1.
- `emojis` metadata (`id`, `type`, `name`, `discord_name`, `debug_name`) stays shared across games. Only the snowflakes differ.

**Data checks to run before deploying services built on kaelly-amqp v1.0.6** (every query must return 0, since rows with game 0 would be refused):

```sql
SELECT 'guilds', COUNT(*) FROM guilds WHERE game = 0
UNION ALL SELECT 'channel_servers', COUNT(*) FROM channel_servers WHERE game = 0
UNION ALL SELECT 'webhook_almanaxes', COUNT(*) FROM webhook_almanaxes WHERE game = 0
UNION ALL SELECT 'webhook_feeds', COUNT(*) FROM webhook_feeds WHERE game = 0
UNION ALL SELECT 'webhook_twitters', COUNT(*) FROM webhook_twitters WHERE game = 0
UNION ALL SELECT 'alignment_books', COUNT(*) FROM alignment_books WHERE game = 0
UNION ALL SELECT 'job_books', COUNT(*) FROM job_books WHERE game = 0
UNION ALL SELECT 'feed_sources', COUNT(*) FROM feed_sources WHERE game = 0
UNION ALL SELECT 'twitter_accounts', COUNT(*) FROM twitter_accounts WHERE game = 0
UNION ALL SELECT 'almanax_news', COUNT(*) FROM almanax_news WHERE game = 0
UNION ALL SELECT 'sets', COUNT(*) FROM sets WHERE game = 0;
```

## 6. Rollout

Messages without a game are refused as soon as a service runs kaelly-amqp v1.0.6. **The deploy order therefore matters:** a service must only start refusing once every service that sends it messages already sets the game.

Today, kaelly-discord, kaelly-rss and kaelly-twitter already set the game on what they publish; the backends' replies do not.

| Phase | Steps | Risk to kaelly-discord |
| --- | --- | --- |
| **A — tag and enforce** | 1. Run the §5 data checks (zero `game = 0` rows); fix rows first.<br>2. Release kaelly-amqp v1.0.6 (guards refuse `ANY_GAME`).<br>3. Deploy **producers of replies and news first**: books, competition, configurator, encyclopedia, rss, twitter. They now set the game on everything they publish.<br>4. Deploy the **consumers**: notifier, metrics.<br>5. Deploy **kaelly-discord last** (DISC-1…9, EMO-2 after M2), with default config. Its consumer guard would drop replies without a game, so every backend must already be on step 3.<br>6. Check the logs for `ANY_GAME` errors after each step. | Low if the order is respected. Step 5 before step 3 would drop every backend reply and break all commands. |
| **B — schema** | 1. Back up the DB.<br>2. Stop books, configurator, twitter and notifier. Apply M1 (§5.3: A servers, B twitter accounts), then deploy DISC-4, DISC-8, BOOK-3, BOOK-6, CONF-3, CONF-4, CONF-7, TWIT-4 and NOTI-3.<br>3. M2 (emoji snowflakes), then deploy EMO-2/3/4; M3 later.<br>M1-A is required before inserting any Touch server, and M1-B before any Touch Twitter account (§5.2). Touch jobs, cities and orders need no migration. | Medium: schema migration. |
| **C — second bot** | 1. Release Kaelly-commands / Kaelly-registrar with CMD-1 / REG-1.<br>2. Register the Touch commands with a Touch registrar deployment.<br>3. Deploy kaellytouch-discord with `GAME=DOFUS_TOUCH`, `RABBITMQ_CLIENT_NAME=KaellyTouch`. | Covered by the tests in §7. |

## 7. Verification

- **Unit tests** in each service:
  - Every reply path, success and failure, returns the request's game (table-driven over games 1 and 2).
  - Unsupported games → `FAILED`, and the source mock is never called.
  - `ANY_GAME` → error log; the message is refused (not published, or not consumed).
- **Repository tests** (sqlite or MySQL in docker): insert game-1 and game-2 rows, then check that every read returns only the requested game and that every delete leaves the other game intact (CONF-4, BOOK-3, ENC-5).
- **Regression check for kaelly-discord:** record the published AMQP messages for each command before and after on staging (debug log in `publish`), then diff them. The only allowed difference is `game` on replies.
- **Two-bot smoke test** on staging, with a fake requester sending `game=2` under client name `KaellyTouch`:
  - kaelly-discord still answers every command.
  - No `KaellyBot-*.answers` queue receives a game-2 reply.
  - `/config get` on the Dofus bot does not show game-2 rows.
  - Kicking the Touch bot from a guild does not remove the Dofus configuration.
  - The notifier does not post game-2 news with the Dofus token.

## 8. Open questions

| # | Question | Default if not answered |
| --- | --- | --- |
| Q1 | ~~Where does the MySQL schema live?~~ | **Decided:** nowhere; migrations are hand-written SQL, applied manually. Read real constraint names with `SHOW CREATE TABLE` before running M1/M2. |
| Q2 | ~~Which features does Touch have at launch?~~ | **Decided:** books (job/align), config and notifications. `/item`, `/set`, `/almanax` and `/map` stay registered but answer "not supported yet". Encyclopedia and competition refuse game 2 as a safety net. |
| Q3 | ~~Which token posts Touch news?~~ | **Decided:** the Touch bot's own token (NOTI-1/2). |
| Q4 | ~~Reporting channel per game?~~ | **Decided:** one shared channel (new/removed guild, set and game reports); each report is sent by the bot of its game. |
| Q5 | ~~Shared tables?~~ | **Decided:** `feed_types` shared. `weapon_area_effects`, `characteristics`, `equipment_types`, `weapon_exceptions` and `almanaxes` stay Dofus-only (only used by features Touch does not support yet). |
| Q6 | ~~Application or guild emojis?~~ | **Decided:** application emojis, one application per game (R11, §4.11). |
| Q7 | ~~Same Twitter account in several games?~~ | **Decided:** yes. `twitter_accounts` is keyed by `(id, game)` (M1, TWIT-4). |
| Q8 | ~~Refuse messages without a game?~~ | **Decided:** refuse immediately, with an `error` log (single maintainer, every module under control). Deploy order matters (§6). |
| Q9 | ~~Dev applications?~~ | **Decided:** one dev application per game; the Touch dev app will be created later. |

## 9. Future work (not in this spec)

- Game in routing keys (`news.rss.dofus_touch`) so consumers can bind per game.
- Dofus Touch sources in encyclopedia (dofusdude support, almanax).
- A game column on `almanaxes`.
- Importing legacy KaellyTOUCH data (Kaelly-migrator): separate spec.
- Serving Touch in encyclopedia (item, set, almanax) and competition (map).
- kaelly-underwatch is obsolete (it monitored the legacy Discord4J KaellyTOUCH) and is not part of this work.
