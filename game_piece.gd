extends RigidBody3D

@export var dragging: bool = false
@export var drag_location: Vector3
@onready var board: Node3D = $"../GameBoard"

var moving: bool = false

func initialize(start_position: Vector3) -> void:
    position = start_position
    drag_location = position

func toggle_drag(set_dragging: bool) -> void:
    dragging = set_dragging
    drag_location = position
    input_ray_pickable = !dragging

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
            board.toggle_drag(true, self)

func _physics_process(_delta: float) -> void:
    if moving:
        move_and_collide(drag_location - position)
        moving = false
