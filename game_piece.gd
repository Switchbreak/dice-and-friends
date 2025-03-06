extends RigidBody3D


@export var dragging: bool = false
@onready var board: Node3D = $"/root/BoardScene/GameBoard"


func initialize(start_position: Vector3) -> void:
    position = start_position


func toggle_drag(set_dragging: bool) -> void:
    dragging = set_dragging
    input_ray_pickable = !dragging


func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
            board.toggle_drag(true, self)


func _physics_process(delta: float) -> void:
    if dragging:
        move_and_collide(board.drag_location - position)
