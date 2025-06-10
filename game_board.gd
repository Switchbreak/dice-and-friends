extends StaticBody3D

@export var piece_scene: PackedScene
@export var drag_location: Vector3

@onready var scene := $"/root/TableScene"
@onready var drag_surface := $"BoardDragSurface/CollisionShape3D"

var drag_object: Node3D

func toggle_drag(drag: bool, set_drag_object: Node3D = null) -> void:
    drag_surface.disabled = !drag

    if set_drag_object != null:
        drag_object = set_drag_object
    if drag_object != null:
        drag_object.toggle_drag(drag)

func _on_input_event(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT && event.pressed:
            var piece = piece_scene.instantiate()
            piece.initialize(event_position)
            scene.add_child(piece)

func _on_board_drag_surface_input_event(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseMotion:
        drag_location = event_position
    if event is InputEventMouseButton:
        if event.button_index == MouseButton.MOUSE_BUTTON_LEFT && !event.pressed:
            toggle_drag(false)
