package amqp

import (
	"errors"
	"testing"
	"time"

	"github.com/rabbitmq/amqp091-go"
	"google.golang.org/protobuf/proto"
)

const testTimeout = time.Second

func newTestBroker(t *testing.T, opts ...Option) *messageBroker {
	t.Helper()

	broker, ok := New("KaellyBot-0", "amqp://guest:guest@localhost:5672", opts...).(*messageBroker)
	if !ok {
		t.Fatal("New() did not return a *messageBroker")
	}
	return broker
}

// The publish guard runs before the connection check, so an untagged message is
// refused even when the broker would otherwise be able to publish it.
func TestPublishGuardRefusesUntaggedMessages(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		publish func(broker *messageBroker, msg *RabbitMQMessage) error
	}{
		{
			name: "emit",
			publish: func(broker *messageBroker, msg *RabbitMQMessage) error {
				return broker.Emit(msg, ExchangeNews, "news.rss", "correlationID")
			},
		},
		{
			name: "request",
			publish: func(broker *messageBroker, msg *RabbitMQMessage) error {
				return broker.Request(msg, ExchangeRequest, "requests.books", "correlationID", "answers")
			},
		},
		{
			name: "reply",
			publish: func(broker *messageBroker, msg *RabbitMQMessage) error {
				return broker.Reply(msg, "correlationID", "KaellyBot-0.answers")
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()

			broker := newTestBroker(t)

			err := test.publish(broker, &RabbitMQMessage{Type: RabbitMQMessage_JOB_GET_BOOK_ANSWER})
			if !errors.Is(err, ErrGameNotSet) {
				t.Errorf("err = %v, want %v", err, ErrGameNotSet)
			}

			// Same message with a game: it now gets past the guard and fails further down.
			err = test.publish(broker, &RabbitMQMessage{
				Type: RabbitMQMessage_JOB_GET_BOOK_ANSWER,
				Game: Game_DOFUS_GAME,
			})
			if !errors.Is(err, ErrMustBeConnected) {
				t.Errorf("err = %v, want %v", err, ErrMustBeConnected)
			}
		})
	}
}

func newDelivery(t *testing.T, msg *RabbitMQMessage, correlationID string) amqp091.Delivery {
	t.Helper()

	body, err := proto.Marshal(msg)
	if err != nil {
		t.Fatalf("proto.Marshal() failed: %v", err)
	}
	return amqp091.Delivery{
		CorrelationId: correlationID,
		ReplyTo:       "KaellyBot-0.answers",
		RoutingKey:    "requests.books",
		Timestamp:     time.Now(),
		Body:          body,
	}
}

// The consumer guard drops untagged messages, hands them to the rejected handler
// and keeps delivering the tagged ones.
func TestConsumeGuardRefusesUntaggedMessages(t *testing.T) {
	t.Parallel()

	consumed := make(chan *RabbitMQMessage, 2)
	rejected := make(chan *RabbitMQMessage, 2)
	rejectedErrs := make(chan error, 2)

	broker := newTestBroker(t, WithRejectedHandler(
		func(ctx Context, message *RabbitMQMessage, err error) {
			if ctx.CorrelationID != "untagged" {
				t.Errorf("rejected correlationID = %q, want %q", ctx.CorrelationID, "untagged")
			}
			rejected <- message
			rejectedErrs <- err
		}))

	deliveries := make(chan amqp091.Delivery, 2)
	deliveries <- newDelivery(t, &RabbitMQMessage{Type: RabbitMQMessage_JOB_GET_BOOK_REQUEST}, "untagged")
	deliveries <- newDelivery(t, &RabbitMQMessage{
		Type: RabbitMQMessage_JOB_GET_BOOK_REQUEST,
		Game: Game_DOFUS_TOUCH,
	}, "tagged")

	eventChan := make(chan connectionEvent, 1)
	done := make(chan interruptionAction, 1)
	go func() {
		done <- broker.listenToMessages(eventChan, func(_ Context, message *RabbitMQMessage) {
			consumed <- message
		}, deliveries)
	}()

	select {
	case message := <-rejected:
		if message.IsGameSet() {
			t.Errorf("rejected game = %v, want %v", message.GetGame(), Game_ANY_GAME)
		}
	case <-time.After(testTimeout):
		t.Fatal("rejected handler was not called for the untagged message")
	}

	if err := <-rejectedErrs; !errors.Is(err, ErrGameNotSet) {
		t.Errorf("rejected err = %v, want %v", err, ErrGameNotSet)
	}

	select {
	case message := <-consumed:
		if message.GetGame() != Game_DOFUS_TOUCH {
			t.Errorf("consumed game = %v, want %v", message.GetGame(), Game_DOFUS_TOUCH)
		}
	case <-time.After(testTimeout):
		t.Fatal("tagged message was not delivered to the consumer")
	}

	eventChan <- shutdown
	select {
	case action := <-done:
		if action != exit {
			t.Errorf("listenToMessages() = %v, want %v", action, exit)
		}
	case <-time.After(testTimeout):
		t.Fatal("listenToMessages did not stop on shutdown")
	}

	if len(consumed) != 0 {
		t.Errorf("consumer received %d unexpected message(s)", len(consumed))
	}
}

// Without WithRejectedHandler, the guard still drops the message and does not panic.
func TestConsumeGuardWithoutRejectedHandler(t *testing.T) {
	t.Parallel()

	broker := newTestBroker(t)

	deliveries := make(chan amqp091.Delivery, 2)
	deliveries <- newDelivery(t, &RabbitMQMessage{Type: RabbitMQMessage_JOB_GET_BOOK_REQUEST}, "untagged")
	deliveries <- newDelivery(t, &RabbitMQMessage{
		Type: RabbitMQMessage_JOB_GET_BOOK_REQUEST,
		Game: Game_DOFUS_GAME,
	}, "tagged")

	consumed := make(chan *RabbitMQMessage, 2)
	eventChan := make(chan connectionEvent, 1)
	go broker.listenToMessages(eventChan, func(_ Context, message *RabbitMQMessage) {
		consumed <- message
	}, deliveries)

	select {
	case message := <-consumed:
		if message.GetGame() != Game_DOFUS_GAME {
			t.Errorf("consumed game = %v, want %v", message.GetGame(), Game_DOFUS_GAME)
		}
	case <-time.After(testTimeout):
		t.Fatal("tagged message was not delivered to the consumer")
	}

	eventChan <- shutdown
}

// A panicking rejected handler must not take the consumer loop down.
func TestConsumeGuardRecoversFromRejectedHandlerPanic(t *testing.T) {
	t.Parallel()

	panicked := make(chan struct{}, 1)
	broker := newTestBroker(t, WithRejectedHandler(
		func(_ Context, _ *RabbitMQMessage, _ error) {
			panicked <- struct{}{}
			panic("rejected handler panics")
		}))

	deliveries := make(chan amqp091.Delivery, 2)
	deliveries <- newDelivery(t, &RabbitMQMessage{Type: RabbitMQMessage_JOB_GET_BOOK_REQUEST}, "untagged")
	deliveries <- newDelivery(t, &RabbitMQMessage{
		Type: RabbitMQMessage_JOB_GET_BOOK_REQUEST,
		Game: Game_DOFUS_GAME,
	}, "tagged")

	consumed := make(chan *RabbitMQMessage, 2)
	eventChan := make(chan connectionEvent, 1)
	go broker.listenToMessages(eventChan, func(_ Context, message *RabbitMQMessage) {
		consumed <- message
	}, deliveries)

	select {
	case <-panicked:
	case <-time.After(testTimeout):
		t.Fatal("rejected handler was not called")
	}

	select {
	case <-consumed:
	case <-time.After(testTimeout):
		t.Fatal("consumer loop stopped after the rejected handler panicked")
	}

	eventChan <- shutdown
}
