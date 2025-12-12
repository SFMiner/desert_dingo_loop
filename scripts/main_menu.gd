# main_menu.gd
# Main menu screen with New Game and Continue options

extends Control

# === NODE REFERENCES ===

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var save_info_label: Label = $VBoxContainer/SaveInfo

# === LIFECYCLE ===

func _ready() -> void:
	_update_continue_button()


func _update_continue_button() -> void:
	"""Update continue button based on save existence."""
	var has_save: bool = SaveSystem.has_save()
	continue_button.visible = has_save
	
	if has_save:
		var info: Dictionary = SaveSystem.get_save_info()
		if not info.is_empty():
			save_info_label.text = "Day %d | Score: %d | %d organisms" % [
				info.get("current_day", 1),
				info.get("total_score", 0),
				info.get("organism_count", 0)
			]
		else:
			save_info_label.text = ""
	else:
		save_info_label.text = ""


# === BUTTON HANDLERS ===

func _on_new_game_pressed() -> void:
	"""Start a new game."""
	AudioManager.play_click_sound()
	
	# Clear any existing save
	SaveSystem.clear_save()
	
	# Initialize new game state
	EcosystemState.start_new_game()
	
	# Transition to game scene
	get_tree().change_scene_to_file("res://scenes/DesertRoom.tscn")


func _on_continue_pressed() -> void:
	"""Continue from saved game."""
	AudioManager.play_click_sound()
	
	# Load saved state
	var success: bool = SaveSystem.load_game()
	
	if success:
		# Transition to game scene
		get_tree().change_scene_to_file("res://scenes/DesertRoom.tscn")
	else:
		# Save was corrupted or missing, start new
		push_warning("Failed to load save, starting new game")
		_on_new_game_pressed()
