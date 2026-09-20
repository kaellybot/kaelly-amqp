package amqp

import "testing"

func TestIsGameSet(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		message *RabbitMQMessage
		want    bool
	}{
		{name: "nil message", message: nil, want: false},
		{name: "unset game", message: &RabbitMQMessage{}, want: false},
		{name: "any game", message: &RabbitMQMessage{Game: Game_ANY_GAME}, want: false},
		{name: "dofus", message: &RabbitMQMessage{Game: Game_DOFUS_GAME}, want: true},
		{name: "dofus touch", message: &RabbitMQMessage{Game: Game_DOFUS_TOUCH}, want: true},
		{name: "dofus retro", message: &RabbitMQMessage{Game: Game_DOFUS_RETRO}, want: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()

			if got := test.message.IsGameSet(); got != test.want {
				t.Errorf("IsGameSet() = %v, want %v", got, test.want)
			}
		})
	}
}

func TestNewReply(t *testing.T) {
	t.Parallel()

	request := &RabbitMQMessage{
		Type:     RabbitMQMessage_ALIGN_GET_BOOK_REQUEST,
		Language: Language_FR,
		Game:     Game_DOFUS_TOUCH,
		UserID:   "userID",
	}

	reply := NewReply(request, RabbitMQMessage_ALIGN_GET_BOOK_ANSWER, RabbitMQMessage_SUCCESS)

	if reply.GetType() != RabbitMQMessage_ALIGN_GET_BOOK_ANSWER {
		t.Errorf("Type = %v, want %v", reply.GetType(), RabbitMQMessage_ALIGN_GET_BOOK_ANSWER)
	}
	if reply.GetStatus() != RabbitMQMessage_SUCCESS {
		t.Errorf("Status = %v, want %v", reply.GetStatus(), RabbitMQMessage_SUCCESS)
	}
	if reply.GetGame() != request.GetGame() {
		t.Errorf("Game = %v, want %v", reply.GetGame(), request.GetGame())
	}
	if reply.GetLanguage() != request.GetLanguage() {
		t.Errorf("Language = %v, want %v", reply.GetLanguage(), request.GetLanguage())
	}
	if !reply.IsGameSet() {
		t.Error("reply built from a tagged request must have its game set")
	}
}

func TestNewFailedReply(t *testing.T) {
	t.Parallel()

	request := &RabbitMQMessage{
		Type:     RabbitMQMessage_JOB_GET_BOOK_REQUEST,
		Language: Language_EN,
		Game:     Game_DOFUS_GAME,
	}

	reply := NewFailedReply(request, RabbitMQMessage_JOB_GET_BOOK_ANSWER)

	if reply.GetStatus() != RabbitMQMessage_FAILED {
		t.Errorf("Status = %v, want %v", reply.GetStatus(), RabbitMQMessage_FAILED)
	}
	if reply.GetType() != RabbitMQMessage_JOB_GET_BOOK_ANSWER {
		t.Errorf("Type = %v, want %v", reply.GetType(), RabbitMQMessage_JOB_GET_BOOK_ANSWER)
	}
	if reply.GetGame() != request.GetGame() {
		t.Errorf("Game = %v, want %v", reply.GetGame(), request.GetGame())
	}
	if reply.GetLanguage() != request.GetLanguage() {
		t.Errorf("Language = %v, want %v", reply.GetLanguage(), request.GetLanguage())
	}
}

// A reply built from a request whose game was never set stays untagged: the
// publish guard is what refuses it, the helper does not invent a game.
func TestNewReplyKeepsUntaggedRequestUntagged(t *testing.T) {
	t.Parallel()

	reply := NewFailedReply(&RabbitMQMessage{}, RabbitMQMessage_JOB_GET_BOOK_ANSWER)

	if reply.IsGameSet() {
		t.Errorf("Game = %v, want %v", reply.GetGame(), Game_ANY_GAME)
	}
}
