package amqp

import "time"

type config struct {
	bindings            []Binding
	retryDelay          time.Duration
	isConnectedCallback func(bool)
	rejectedHandler     RejectedHandler
}

type Option func(*config)

// WithBindings configures queue bindings to create
// Empty routingKey is set to unique queue name by default.
func WithBindings(bindings ...Binding) Option {
	return func(cfg *config) {
		cfg.bindings = append(cfg.bindings, bindings...)
	}
}

// WithRetryDelay configures the retry delay.
func WithRetryDelay(d time.Duration) Option {
	return func(cfg *config) {
		cfg.retryDelay = d
	}
}

// WithIsConnectedCallback sets the callback for connection status.
func WithIsConnectedCallback(callback func(bool)) Option {
	return func(cfg *config) {
		cfg.isConnectedCallback = callback
	}
}

// WithRejectedHandler sets the handler called for every incoming message
// refused by the consumer guards, such as a message whose game is ANY_GAME.
func WithRejectedHandler(handler RejectedHandler) Option {
	return func(cfg *config) {
		cfg.rejectedHandler = handler
	}
}
