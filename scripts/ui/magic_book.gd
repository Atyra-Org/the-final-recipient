extends CanvasLayer
class_name MagicBook

signal book_opened
signal book_closed

var is_open: bool = false

@onready var book_container: Control = $BookContainer
@onready var close_button: Button = $BookContainer/CloseButton
@onready var book_texture: TextureRect = $BookContainer/BookTexture

func _ready() -> void:
	add_to_group("magic_book")
	
	book_container.hide()
	
	close_button.pressed.connect(close_book)
	
func toggle_book() -> void:
	if is_open:
		close_book()
	else:
		open_book()
		
func open_book() -> void:
	if is_open:
		return
	
	is_open = true
	book_container.show()
	book_opened.emit()
	
func close_book() -> void:
	if not is_open:
		return
	
	is_open = false
	book_container.hide()
	book_closed.emit()
