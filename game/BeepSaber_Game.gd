# This file contains the main game logic for the BeepSaber demo implementation
#
extends Spatial

onready var left_controller := $OQ_ARVROrigin/OQ_LeftController;
onready var right_controller := $OQ_ARVROrigin/OQ_RightController;

onready var left_saber := $OQ_ARVROrigin/OQ_LeftController/LeftLightSaber;
onready var right_saber := $OQ_ARVROrigin/OQ_RightController/RightLightSaber;

onready var ui_raycast := $OQ_ARVROrigin/OQ_RightController/Feature_UIRayCast;

onready var cube_template = preload("res://game/BeepCube.tscn").instance();
onready var wall_template = preload("res://game/Wall/Wall.tscn").instance();

var cube_left = null
var cube_right = null

onready var track = $Track;

onready var song_player := $SongPlayer;

const COLOR_LEFT := Color(1.0, 0.1, 0.1, 1.0);
const COLOR_RIGHT := Color(0.1, 0.1, 1.0, 1.0);

const CUBE_HEIGHT_OFFSET = 0.4
const WALL_HEIGHT = 3.0


var _current_map = null;
var _current_note_speed = 1.0;
var _current_info = null;
var _current_note = 0;
var _current_obstacle = 0;


var _high_score = 0;

var _current_points = 0;
var _current_multiplier = 1;
var _current_combo = 0;

var _in_wall = false;

func restart_map():
	song_player.play(0.0);
	song_player.volume_db = 0.0;
	_in_wall = false;
	_current_note = 0;
	_current_obstacle = 0;
	_current_points = 0;
	_current_multiplier = 1;
	_current_combo = 0;

	_display_points();

	for c in $Track.get_children():
		c.visible = false;
		$Track.remove_child(c);
		c.queue_free();

	$MainMenu_OQ_UI2DCanvas.visible = false;

	left_saber.show();
	right_saber.show();
	ui_raycast.visible = false;
	$EndScore_OQ_UILabel.visible = false;
	$Multiplier_Label.visible=true;
	$Point_Label.visible=true;


func continue_map():
	song_player.play(song_player.get_playback_position());
	$MainMenu_OQ_UI2DCanvas.visible = false;

	left_saber.show();
	right_saber.show();
	ui_raycast.visible = false;


func start_map(info, map_data):
	_current_map = map_data;
	_current_info = info;
	var snd_file = File.new()
	snd_file.open(info._path + info._songFilename, File.READ) #works whether it's a resource or a file
	var stream = AudioStreamOGGVorbis.new()
	stream.data = snd_file.get_buffer(snd_file.get_len())
	snd_file.close()
	song_player.stream = stream;
	restart_map();


func show_menu():
	if ($MainMenu_OQ_UI2DCanvas.visible): return;

	if (song_player.playing):
		song_player.stop();
		_main_menu.set_mode_continue();
	else:
		_main_menu.set_mode_game_start();
		left_saber.hide();
		right_saber.hide();
		$Multiplier_Label.visible=false;
		$Point_Label.visible=false;

	ui_raycast.visible = true;
	$MainMenu_OQ_UI2DCanvas.visible = true;

# when the song ended we want to display the current score and
# the high score
func _end_song_display():
	if (_current_points > _high_score):
		_high_score = _current_points;

	$EndScore_OQ_UILabel.set_label_text("Congratulations\nYour Score: %d\nHigh Score: %d" %[_current_points, _high_score]);
	$EndScore_OQ_UILabel.visible = true;
	song_player.stop();
	show_menu();


const beat_distance = 4.0;
const CUBE_DISTANCE = 0.5;
const CUBE_ROTATIONS = [180, 0, 270, 90, -135, 135, -45, 45, 0];

func _spawn_cube(note, current_beat):
	var cube = null;
	if (note._type == 0):
		cube = cube_left.duplicate();
	elif (note._type == 1):
		cube = cube_right.duplicate();
	else:
		return;

	track.add_child(cube);

	var line = -(CUBE_DISTANCE * 3.0 / 2.0) + note._lineIndex * CUBE_DISTANCE;
	var layer = CUBE_DISTANCE + note._lineLayer * CUBE_DISTANCE;

	var rotation_z = deg2rad(CUBE_ROTATIONS[note._cutDirection]);

	var distance = note._time - current_beat;

	cube.transform.origin = Vector3(
		line,
		CUBE_HEIGHT_OFFSET + layer,
		-distance * beat_distance);

	cube._cube_mesh_orientation.rotation.z = rotation_z;
	if note._cutDirection==8:
		cube._cube_mesh_orientation.rotation.y = deg2rad(180);

	cube._note = note;

# constants used to interpret the '_type' field in map obstacles
const WALL_TYPE_FULL_HEIGHT = 0;
const WALL_TYPE_CROUCH = 1;

func _spawn_wall(obstacle, current_beat):
	# instantiate new wall from template
	var wall = wall_template.duplicate();
	wall.duplicate_create();# gives it its own unique mesh and collision shape
	
	var height = 0;
	
	if (obstacle._type == WALL_TYPE_FULL_HEIGHT):
		wall.height = WALL_HEIGHT;
		height = 0;
	elif (obstacle._type == WALL_TYPE_CROUCH):
		wall.height = WALL_HEIGHT / 2.0;
		height = WALL_HEIGHT / 2.0;
	else:
		return;

	track.add_child(wall);

	var line = -(CUBE_DISTANCE * 3.0 / 2.0) + obstacle._lineIndex * CUBE_DISTANCE;
	
	var distance = obstacle._time - current_beat;

	wall.transform.origin = Vector3(line,height,-distance * beat_distance);
	wall.depth = beat_distance * obstacle._duration;
	wall.width = CUBE_DISTANCE * obstacle._width;
	
	# walls have slightly difference origins offsets than cubes do, so we must
	# translate them by half a cube distance to correct for the misalignment.
	wall.translate(Vector3(-CUBE_DISTANCE/2.0,-CUBE_DISTANCE/2.0,0.0));

	wall._obstacle = obstacle;


func _process_map(dt):
	if (_current_map == null):
		return;

	var beats_ahead = Options.beats_ahead
	var current_time = song_player.get_playback_position();
	var bps = _current_info._beatsPerMinute / 60.0;
	var current_beat = current_time * bps;

	# spawn notes
	var n =_current_map._notes;
	while (_current_note < n.size() && n[_current_note]._time <= current_beat+beats_ahead):
		_spawn_cube(n[_current_note], current_beat);
		_current_note += 1;

	# spawn obstacles (walls)
	var o = _current_map._obstacles;
	while (_current_obstacle < o.size() && o[_current_obstacle]._time <= current_beat+beats_ahead):
		_spawn_wall(o[_current_obstacle], current_beat);
		_current_obstacle += 1;

	var speed = Vector3(0.0, 0.0, beat_distance * bps);

	for c in track.get_children():
		c.translate(speed * dt);

		var depth = CUBE_DISTANCE
		if c is Wall:
			# compute wall's depth based on duration
			depth = beat_distance * c._obstacle._duration

		# remove children that go to far
		if ((c.global_transform.origin.z - depth) > 2.0):
			c.queue_free();
			_reset_combo();

	if (song_player.get_playback_position() >= song_player.stream.get_length()-1):
		_end_song_display();

# with this variable we track the movement volume of the controller
# since the last cut (used to give a higher score when moved a lot)
var _controller_movement_aabb = [
	AABB(), AABB(), AABB()
]

func _update_controller_movement_aabb(controller : ARVRController):
	var id = controller.controller_id
	var aabb = _controller_movement_aabb[id].expand(controller.global_transform.origin);
	_controller_movement_aabb[id] = aabb;


func _check_and_update_saber(controller : ARVRController, saber: Area):
	# to allow extending/sheething the saber while not playing a song
	if (!song_player.playing):
		if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.XA) ||
			controller._button_just_pressed(vr.CONTROLLER_BUTTON.YB)):
				if (!saber._anim.is_playing()):
					if (saber.is_extended()): saber.hide();
					else: saber.show();
	
	# check for saber rumble (only when extended and not already rumbling)
	# this check is necessary to not overwrite a rumble set from somewhere else
	# (in this case it can come from cutting cubes)
	if (!controller.is_simple_rumbling()): 
		if (_in_wall):
			# weak rumble on both controllers when player is inside wall
			controller.set_rumble(0.1);
		elif (saber.get_overlapping_areas().size() > 0 || saber.get_overlapping_bodies().size() > 0):
			# strong rumble when saber is cutting into wall or other saber
			controller.set_rumble(0.5);
		else:
			controller.set_rumble(0.0);


var left_saber_end = Vector3()
var right_saber_end = Vector3()
var left_saber_end_past = Vector3()
var right_saber_end_past = Vector3()
var last_dt = 0.0


func _update_saber_end_variabless(dt):
	left_saber_end_past = left_saber_end
	right_saber_end_past = right_saber_end
	left_saber_end = left_controller.global_transform.origin + left_saber.global_transform.basis.y
	right_saber_end = right_controller.global_transform.origin + right_saber.global_transform.basis.y
	last_dt = dt


func _physics_process(dt):
	if (vr.button_just_released(vr.BUTTON.ENTER)):
		show_menu();

	if (song_player.playing):
		_process_map(dt);
		_update_controller_movement_aabb(left_controller);
		_update_controller_movement_aabb(right_controller);
	
	_check_and_update_saber(left_controller, left_saber);
	_check_and_update_saber(right_controller, right_saber);
	
	_update_saber_end_variabless(dt)
	
	_update_level(dt);

var _main_menu = null;
var _spectrum = null;
var _spectrum_nodes = [];

# update the level animations; at the moment this is only the basic
# spectrum analyzer
func _update_level(dt):
	var VU_COUNT = _spectrum_nodes.size();
	var FREQ_MAX = 11050.0
	var MIN_DB = 60.0

	var prev_hz = 100
	for i in range(1,VU_COUNT+1):
		var hz = i * FREQ_MAX / VU_COUNT;
		var f = _spectrum.get_magnitude_for_frequency_range(prev_hz,hz)
		var energy = clamp((MIN_DB + linear2db(f.length()))/MIN_DB,0,1)

		_spectrum_nodes[i-1].translation.y = energy * 10.0;

		prev_hz = hz

# create the level data that is displayed
func _setup_level():
	
	# create a specrum analyzer
	AudioServer.add_bus_effect(0, AudioEffectSpectrumAnalyzer.new());
	_spectrum = AudioServer.get_bus_effect_instance(0,0);
	# and create some cubes to display it in the level (updated in _update_level(dt))
	var s = $Level/SpectrumBar;
	_spectrum_nodes.push_back(s);
	for  i in range(0, 7):
		s = s.duplicate()
		$Level.add_child(s);
		s.translation.x += 2.0;
		_spectrum_nodes.push_back(s);


func _ready():
	_main_menu = $MainMenu_OQ_UI2DCanvas.find_node("BeepSaberMainMenu", true, false);
	_main_menu.initialize(self);

	cube_left = cube_template.duplicate();
	cube_right = cube_template.duplicate();
	cube_left.duplicate_create(COLOR_LEFT);
	cube_right.duplicate_create(COLOR_RIGHT);

	left_saber._mat.set_shader_param("color", COLOR_LEFT);
	left_saber.type = 0;
	right_saber._mat.set_shader_param("color", COLOR_RIGHT);
	right_saber.type = 1;
	
	# This is a workaround for now to orient correctly for the Vive controllers
	if (vr.active_arvr_interface_name == "OpenVR"):
		left_saber.rotation_degrees.x = -90;
		right_saber.rotation_degrees.x = -90;
		ui_raycast.rotation_degrees.x = 0;

	$MainMenu_OQ_UI2DCanvas.visible = false;
	show_menu();
	_setup_level();


# cut the cube by creating two rigid bodies and using a CSGBox to create
# the cut plane
func _create_cut_rigid_body(_sign, cube : Spatial, cutplane : Plane, cut_distance, controller_speed):
	var rigid_body_half = RigidBody.new();
	
	# the original cube mesh
	var csg_cube = CSGMesh.new();
	csg_cube.mesh = cube._mesh;
	csg_cube.transform = cube._cube_mesh_orientation.transform;
	
	# using a box to cut away part of the mesh
	var csg_cut = CSGBox.new();
	csg_cut.operation = CSGShape.OPERATION_SUBTRACTION;
	csg_cut.material = load("res://game/BeepCube_Cut.material");
	csg_cut.width = 1; csg_cut.height = 1;csg_cut.depth = 1;

	# transform the normal into the orientation of the actual cube mesh
	var normal = csg_cube.transform.basis.inverse() * cutplane.normal;
	csg_cut.look_at_from_position(-(cut_distance - _sign*0.5) * normal, normal, Vector3(0,1,0));
	csg_cube.add_child(csg_cut);

	# Next we are adding a simple collision cube to the rigid body. Note that
	# his is really just a very crude approximation of the actual cut geometry
	# but for now it's enough to give them some physics behaviour
	if Options.enable_cut_collisions:
		var coll = CollisionShape.new();
		coll.shape = BoxShape.new();
		coll.shape.extents = Vector3(0.25, 0.25, 0.125);
		coll.look_at_from_position(-cutplane.normal*_sign*0.125, cutplane.normal, Vector3(0,1,0));
		rigid_body_half.add_child(coll);

	# set a phyiscs material for some more bouncy behaviour
	rigid_body_half.physics_material_override = load("res://game/BeepCube_Cut.phymat");

	rigid_body_half.add_child(csg_cube);
	add_child(rigid_body_half);
	rigid_body_half.global_transform = cube.global_transform;

	# some impulse so the cube halfs get some movement
	rigid_body_half.apply_central_impulse(-_sign * cutplane.normal +  controller_speed);

	# attach the sound effect only to one of the halfs; I attach them here so
	# it gets deleted when the body is deleted later
	if _sign == 1 and not Options.mute_cut_sound:
		var snd = AudioStreamPlayer.new();
		snd.stream = preload("res://game/data/beepcube_cut.ogg");
		rigid_body_half.add_child(snd);
		snd.play();

	# delete the rigid body after 2 seconds; this only works here because we are
	# at the end of this function and do not need the rigid body for anything else
	yield(get_tree().create_timer(2.0), "timeout")
	rigid_body_half.queue_free()



func _reset_combo():
	_current_multiplier = 1;
	_current_combo = 0;
	_display_points();


func _update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor):
	#if (beat_accuracy == 0.0 || cut_angle_accuracy == 0.0 || cut_distance_accuracy == 0.0):
	#	_reset_combo();
	#	return;

	# check if we hit the cube with the correctly colored saber
	if (saber.type != cube._note._type):
		_reset_combo();
		return;

	_current_combo += 1;
	_current_multiplier = 1 + round(min((_current_combo / 10), 7.0));

	# point computation based on the accuracy of the swing
	var points = 0;
	points += beat_accuracy * 50;
	points += cut_angle_accuracy * 50;
	points += cut_distance_accuracy * 50;
	points += points * travel_distance_factor;

	points = round(points);
	_current_points += points * _current_multiplier;

	_display_points();


func _display_points():
	$Point_Label.set_label_text("Score: %6d" % _current_points);
	$Multiplier_Label.set_label_text("x %d\nCombo %d" %[_current_multiplier, _current_combo])

# perform the necessay computations to cut a cube with the saber
func _cut_cube(controller : ARVRController, saber : Area, cube : Spatial):
	# perform haptic feedback for the cut
	controller.simple_rumble(0.75, 0.1);
	var o = controller.global_transform.origin;
	var saber_end : Vector3
	var saber_end_past : Vector3
	if(controller.controller_id == 1): # Check if it's the left controller
		saber_end = left_saber_end
		saber_end_past = left_saber_end_past
	else:
		saber_end = right_saber_end
		saber_end_past = right_saber_end_past
	
	var cutplane := Plane(o, saber_end, saber_end_past + (beat_distance *_current_info._beatsPerMinute * last_dt / 30) * Vector3(0, 0, 1)); # Account for relative position to track speed
	var cut_distance = cutplane.distance_to(cube.global_transform.origin);
	
	var controller_speed : Vector3 = (saber_end - saber_end_past) / (5*last_dt) + 0.2*(beat_distance *_current_info._beatsPerMinute / 60) * Vector3(0, 0, 1) # Account for inertial track speed
	
	# only spawn cut bodies if instant kill is 'off'
	if not Options.cube_instant_kill:
		_create_cut_rigid_body(-1, cube, cutplane, cut_distance, controller_speed);
		_create_cut_rigid_body( 1, cube, cutplane, cut_distance, controller_speed);

	# compute the angle between the cube orientation and the cut direction
	var cut_direction_xy = -Vector3(controller_speed.x, controller_speed.y, 0.0).normalized();
	var cut_angle_accuracy = cube._cube_mesh_orientation.global_transform.basis.y.dot(cut_direction_xy);
	cut_angle_accuracy = clamp((cut_angle_accuracy-0.7)/0.3, 0.0, 1.0);
	var cut_distance_accuracy = clamp((0.1 - abs(cut_distance))/0.1, 0.0, 1.0);
	var travel_distance_factor = _controller_movement_aabb[controller.controller_id].get_longest_axis_size();
	travel_distance_factor = clamp((travel_distance_factor-0.5)/0.5, 0.0, 1.0);

	# allows a bit of save margin where the beat is considered 100% correct
	var beat_accuracy = clamp((1.0 - abs(cube.global_transform.origin.z)) / 0.5, 0.0, 1.0);

	_update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor);

	# reset the movement tracking volume for the next cut
	_controller_movement_aabb[controller.controller_id] = AABB(controller.global_transform.origin, Vector3(0,0,0));

	#vr.show_dbg_info("cut_accuracy", str(beat_accuracy) + ", " + str(cut_angle_accuracy) + ", " + str(cut_distance_accuracy) + ", " + str(travel_distance_factor));
	# delete the original cube; we have two new halfs created above
	cube.queue_free();

# quiets song when player enters into a wall
func _quiet_song():
	song_player.volume_db = -15.0;

# restores song volume when player leaves wall
func _louden_song():
	song_player.volume_db = 0.0;

func _on_LeftLightSaber_area_entered(area : Area):
	if (area.is_in_group("beepcube")):
		_cut_cube(left_controller, left_saber, area.get_parent().get_parent());


func _on_RightLightSaber_area_entered(area : Area):
	if (area.is_in_group("beepcube")):
		_cut_cube(right_controller, right_saber, area.get_parent().get_parent());

func _on_PlayerHead_area_entered(area):
	if area.is_in_group("wall"):
		if not _in_wall:
			_quiet_song();
		
		_in_wall = true;

func _on_PlayerHead_area_exited(area):
	if area.is_in_group("wall"):
		if _in_wall:
			_louden_song();
		
		_in_wall = false;
