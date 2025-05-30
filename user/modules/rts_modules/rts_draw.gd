class_name RTSDraw extends UserModule

signal start
signal stop

enum Mode {
	Point,
	Line,
	Box,
	Box_Formation
}
var selected_mode: Mode = Mode.Point

var object: PaintObject

func start_draw(_user: User) -> void:
	selected_mode = Mode.Box_Formation
	start.emit()

func stop_draw(_user: User) -> void:
	stop.emit()

func update(_user: User, _delta: float) -> void:
	pass
