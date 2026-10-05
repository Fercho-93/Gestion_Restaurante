extends Node2D
## Escena principal: une el mundo isométrico con el HUD.

@onready var floor_grid: Node2D = $World/IsoFloor
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	# Centrar la cámara en el centro del local.
	camera.position = Iso.cell_to_screen(floor_grid.size / 2)
	floor_grid.cell_tapped.connect(_on_cell_tapped)


func _on_cell_tapped(cell: Vector2i) -> void:
	hud.show_info("%s · celda (%d, %d)" % [floor_grid.zone_name_at(cell), cell.x, cell.y])
