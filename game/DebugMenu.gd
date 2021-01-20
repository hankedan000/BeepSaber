extends Panel

onready var cube_instant_kill = $Margin/VBox/Scroll/DebugItems/CubeOptions/CubeInstantKill
onready var cube_no_collision = $Margin/VBox/Scroll/DebugItems/CubeOptions/CubeNoCollisions

onready var beats_ahead_slider = $Margin/VBox/Scroll/DebugItems/BeatsAhead/BeatsAheadSlider
onready var beats_ahead_indicator = $Margin/VBox/Scroll/DebugItems/BeatsAhead/BeatsAheadIndicator

func _ready():
	cube_instant_kill.pressed = Options.cube_instant_kill
	cube_no_collision.pressed = Options.cube_no_collisions
	
	beats_ahead_slider.value = Options.beats_ahead
	beats_ahead_indicator.text = str(Options.beats_ahead)

func _on_CubeInstantKill_toggled(button_pressed):
	Options.cube_instant_kill = button_pressed

func _on_CubeNoCollisions_toggled(button_pressed):
	Options.cube_no_collisions = button_pressed

func _on_BeatsAheadSlider_value_changed(value):
	Options.beats_ahead = int(value)
	beats_ahead_indicator.text = str(Options.beats_ahead)
