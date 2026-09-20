package amqp

// NewReply builds a reply carrying the request's game and language.
// Using it instead of a bare literal guarantees that the answer is tagged
// with the game the requester asked for (R2).
func NewReply(request *RabbitMQMessage, msgType RabbitMQMessage_Type,
	status RabbitMQMessage_Status) *RabbitMQMessage {
	return &RabbitMQMessage{
		Type:     msgType,
		Status:   status,
		Game:     request.GetGame(),
		Language: request.GetLanguage(),
	}
}

// NewFailedReply builds a FAILED reply carrying the request's game and language.
func NewFailedReply(request *RabbitMQMessage, msgType RabbitMQMessage_Type) *RabbitMQMessage {
	return NewReply(request, msgType, RabbitMQMessage_FAILED)
}

// IsGameSet reports whether game != ANY_GAME.
func (x *RabbitMQMessage) IsGameSet() bool {
	return x.GetGame() != Game_ANY_GAME
}
