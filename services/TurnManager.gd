extends Node2D

onready var game = get_tree().current_scene
onready var turn_timer = get_node("TurnTimer")
onready var card_action_timer = get_node("CardActionTimer")

# the purpose of this Node is to manage turns, i.e.
# the actions of each active card on each cycle,
# the actions of players on each turn (when they can play cards)

# keep track of how many player and card turns have been completed
var elapsed_player_turns = 0
var elapsed_card_turns = 0

func start():
	# start game timer
	turn_timer.start()
	card_action_timer.start()
	game.player1_avatar.card_manager.deck.shuffle()
	game.player2_avatar.card_manager.deck.shuffle()

func stop():
	turn_timer.stop()
	card_action_timer.stop()

func _on_TurnTimer_timeout():
	game.player1_avatar.play_cards()
	game.player2_avatar.play_cards()

func _get_attackable_cards(cards):
	var attackable_cards = []
	for card in cards:
		if "mudcombat:hasHealthPoints" in card:
			attackable_cards.append(card)
	return attackable_cards

func _handle_basic_attack(player_avatar_scene, opponent_avatar_scene, opponent_attackable_cards):
	# attack the enemy avatar if they have no protection
	if len(opponent_attackable_cards) == 0:
		opponent_avatar_scene.health_bar.remove_health(3)
		if opponent_avatar_scene.health_bar.health_value <= 0:
			game.end_battle()
		return
	
	# otherwise attack the first card
	var destroyed = opponent_avatar_scene.card_manager.damage_card(opponent_attackable_cards[0]["@id"], 1)
	if destroyed != null:
		game._remove_card_with_urlid(destroyed)

func _handle_unknown_action(actor, action):
	if "mudlogic:actAt" in action:
		game.federation_manager.perform_action(action["mudlogic:actAt"], action, actor)
	else:
		print("ERR _handle_unknown_action given an action without required mudlogic:actAt property")
		print(action["@id"])

func _play_card_actions(player_avatar_scene, opponent_avatar_scene):
	elapsed_card_turns += 1
	var opponent_attackable_cards = _get_attackable_cards(opponent_avatar_scene.card_manager.active_cards)
	for action in player_avatar_scene.card_manager.play_card_actions():
		var actor = action[0]
		action = action[1]
		
		if action["@id"] == Globals.BUILT_IN_ACTIONS.BASIC_ATTACK:
			_handle_basic_attack(player_avatar_scene, opponent_avatar_scene, opponent_attackable_cards)
		else:
			_handle_unknown_action(actor, action)

# allow active cards to make attacks
func _on_CardActionTimer_timeout():
	elapsed_player_turns += 1
	self._play_card_actions(game.player1_avatar, game.player2_avatar)
	self._play_card_actions(game.player2_avatar, game.player1_avatar)
