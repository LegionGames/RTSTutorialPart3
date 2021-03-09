extends Node2D


var dragging = false
var selected = []
var weakref_selected = []
var drag_start = Vector2.ZERO
var select_rectangle = RectangleShape2D.new()

onready var select_draw = $SelectDraw


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			for unit in weakref_selected:
				if unit.get_ref():
					unit.get_ref().deselect()
			selected = []
			weakref_selected = []
			dragging = true
			drag_start = event.position
		elif dragging:
			dragging = false
			select_draw.update_status(drag_start, event.position, dragging)
			var drag_end = event.position
			select_rectangle.extents = (drag_end - drag_start) / 2
			var space = get_world_2d().direct_space_state
			var query = Physics2DShapeQueryParameters.new()
			query.set_shape(select_rectangle)
			query.transform = Transform2D(0, (drag_end + drag_start)/2)
			selected = space.intersect_shape(query, 100)
			for unit in selected:
				if unit.collider.is_in_group("unit"):
					if unit.collider.unit_owner == 0:
						unit.collider.select()
						weakref_selected.append(weakref(unit.collider))
	if dragging:
		if event is InputEventMouseMotion:
			select_draw.update_status(drag_start, event.position, dragging)
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT:
		$MoveAnimation.position = event.position
		$MoveAnimation.frame = 0


func get_movement_group():
	return weakref_selected
