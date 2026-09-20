# Kaelly-amqp

[![Golangci-lint](https://github.com/kaellybot/kaelly-amqp/actions/workflows/golangci-lint.yml/badge.svg)](https://github.com/kaellybot/kaelly-amqp/actions/workflows/golangci-lint.yml)
[![Test](https://github.com/kaellybot/kaelly-amqp/actions/workflows/test.yml/badge.svg)](https://github.com/kaellybot/kaelly-amqp/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/kaellybot/kaelly-amqp/branch/main/graph/badge.svg)](https://codecov.io/gh/kaellybot/kaelly-amqp) 

Library to discuss with RabbitMQ via Protobuf, built in Go 

## Installation

This project uses the `protoc` command to generate Go files from proto files. 

- To install the protobuf compiler:
```
apt install protobuf-compiler
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

- To generate new go file based on proto source:
```
protoc --go_out=. rabbitmq.proto
```
## Game isolation

Several bots share this RabbitMQ: `kaellybot-discord` (`DOFUS_GAME`) and `kaellytouch-discord`
(`DOFUS_TOUCH`). `RabbitMQMessage.game` is what keeps them apart, and because `ANY_GAME` is the
proto3 zero value, a message whose game was never set is indistinguishable from one explicitly
tagged `ANY_GAME`. The library therefore refuses both, on publish and on consume.

See [`docs/specs/game-isolation.md`](docs/specs/game-isolation.md) for the full specification.

### Guards

- **Publishing** — `Emit`, `Request` and `Reply` check the game before anything else. A message
  with `ANY_GAME` is logged at `error` (type, exchange, routing key, correlation ID), is **not
  published**, and the call returns `ErrGameNotSet`.
- **Consuming** — an incoming message with `ANY_GAME` is logged at `error` (type, correlation ID,
  reply-to), acked, and never passed to the consumer. `WithRejectedHandler` receives it so the
  service can react, for instance by answering the user instead of letting them wait for a reply
  that will never come.

Neither guard can be turned off. The library cannot build a typed `FAILED` answer itself, so a
backend receiving an untagged request only logs it; the requester relies on its own timeout.

### Helpers

Build replies with `NewReply` / `NewFailedReply` rather than a bare literal: they carry the
request's game and language over to the answer.

```go
func handleRequest(ctx amqp.Context, request *amqp.RabbitMQMessage) {
	if request.GetGame() != amqp.Game_DOFUS_GAME {
		// The service does not serve this game: answer FAILED with the request's game.
		reply := amqp.NewFailedReply(request, amqp.RabbitMQMessage_JOB_GET_BOOK_ANSWER)
		_ = broker.Reply(reply, ctx.CorrelationID, ctx.ReplyTo)
		return
	}

	reply := amqp.NewReply(request, amqp.RabbitMQMessage_JOB_GET_BOOK_ANSWER, amqp.RabbitMQMessage_SUCCESS)
	reply.JobGetBookAnswer = answer
	_ = broker.Reply(reply, ctx.CorrelationID, ctx.ReplyTo)
}
```

`(*RabbitMQMessage).IsGameSet()` reports whether the game differs from `ANY_GAME`; it is nil-safe.

```go
broker := amqp.New(clientID, address,
	amqp.WithRejectedHandler(func(ctx amqp.Context, msg *amqp.RabbitMQMessage, err error) {
		// Answer the pending request identified by ctx.CorrelationID.
	}),
)
```

### Contract rules

These rules apply to every service on this bus. R1–R4 are the ones this library enforces or
supports directly; the others are listed so a service knows what is expected of it.

| ID | Rule |
| --- | --- |
| **R1** | Every published message has `game != ANY_GAME`. |
| **R2** | A reply (success **or** failure) has `game = request.game`. Replies are built with `NewReply` / `NewFailedReply`, never with a bare literal. |
| **R3** | A news message has the game of the data it describes: the DB row, or the source that was polled. The game is never hard-coded in a mapper; it is passed in as a parameter. |
| **R4** | A consumer validates `request.game` before any other work. `ANY_GAME` is refused by the guards above and never reaches the consumer. A game the service does not support gets a `FAILED` reply carrying the request's game. |
| **R5** | Every SQL read or write on a table that has a `game` column filters or sets the game, including preloads, joins, deletes and cascades. |
| **R6** | Every external call that depends on the game (dofusdude game path, Discord token or application) chooses its target from the game. When there is no target for that game, the call is not made and the error is explicit. |
| **R7** | In-memory stores and caches holding per-game data are keyed by game. |
| **R8** | Each bot uses its own AMQP client ID, so each has its own `<clientID>.answers` queue. |
| **R9** | Logs for request handling include the game. |
| **R10** | Reference data can differ per game: `jobs`, `cities`, `orders`, `servers`, their `*_labels`, feeds, twitter accounts, almanax news. Every lookup is scoped to one game. `jobs`, `cities`, `orders`, `servers` and `twitter_accounts` are identified by `(id, game)`. |
| **R11** | One Discord application per game (plus one dev application per game). Every Discord resource — token, application ID, emojis, commands, news channels, branding — is resolved from the game of the message or data being handled, never from the service's own identity. |

### Client ID and queue names

The `clientID` passed to `New` prefixes every queue this client declares and consumes from:
a binding on queue `answers` becomes `<clientID>.answers`, and the `replyTo` of a published
request is rewritten the same way. **These queues are durable**, so changing a client ID strands
the old queue and its messages. Each bot must use its own client ID — that is what gives each one
its own answer queue — and existing ones must keep the name they already have.
