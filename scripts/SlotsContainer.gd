extends PanelContainer

@onready var close_button : Button = %CloseButton
@onready var slot_grid : Control = %SlotGrid

var is_open = true
var open_size : Vector2
var start_pos : Vector2

func _ready():
	open_size = size
	start_pos = position
	set_open()
	
func toggle_open_close():
	is_open = !is_open
	if is_open:
		set_open()
	else: 
		set_closed()

func set_open():
	size = open_size
	close_button.text = "HIDE SLOTS"
	print(str(Vector2(size.x - close_button.size.x - 3, 3)))
	close_button.position = Vector2(size.x - close_button.size.x - 3, 3)
	print(str(size.x))
	print(str(close_button.size.x))
	print(str(close_button.position))
	slot_grid.visible = true
	position = start_pos
	get_parent().show_organisms_container()

func set_closed():
	slot_grid.visible = false
	close_button.text = "SHOW SLOTS"
#	position.x = position.x + size.x - close_button.size.x
	size.y = close_button.size.y
	get_parent().hide_organisms_container()

func _on_close_button_pressed() -> void:
	toggle_open_close()
