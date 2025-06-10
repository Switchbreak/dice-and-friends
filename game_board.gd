extends StaticBody3D

@export var piece_scene: PackedScene
@export var drag_location: Vector3

@onready var scene := owner
@onready var drag_surface := $"BoardDragSurface/CollisionShape3D"

var drag_object: Node3D
var drag_offset: Vector3
var drag_offset_set: bool = false
var pieces: Array[Node3D] = []

func toggle_drag(drag: bool, set_drag_object: Node3D = null) -> void:
    drag_surface.disabled = !drag

    if set_drag_object != null:
        drag_object = set_drag_object
        drag_offset_set = false
    if drag_object != null:
        drag_object.toggle_drag(drag)

@rpc("any_peer", "call_local", "reliable")
func spawn_piece(event_position: Vector3) -> void:
    var piece = piece_scene.instantiate()
    piece.initialize(event_position)
    scene.add_child(piece)
    pieces.append(piece)

@rpc("any_peer", "call_local", "unreliable")
func drag_piece(index: int, event_position: Vector3) -> void:
    if pieces.size() > index:
        pieces[index].drag_location = event_position
        pieces[index].moving = true

func _on_input_event(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT && event.pressed:
            spawn_piece.rpc(event_position)

func _on_board_drag_surface_input_event(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseMotion:
        if drag_object != null:
            if not drag_offset_set:
                drag_offset = drag_object.position - event_position
                drag_offset_set = true

            var index := pieces.find(drag_object)
            drag_piece.rpc(index, event_position + drag_offset)
    if event is InputEventMouseButton:
        if event.button_index == MouseButton.MOUSE_BUTTON_LEFT && !event.pressed:
            toggle_drag(false)
