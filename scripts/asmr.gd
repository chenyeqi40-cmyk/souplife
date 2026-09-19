extends Node
var game
var voices: Array = []
var pans: Array = []
var next_voice=0
var rain: AudioStreamPlayer
var boil: AudioStreamPlayer
var foley_volume=1.0
var ambience_volume=.85
const FOLEY_GAIN_DB=11.0
const MIX_BUS="StallMix"
var boil_strength=0.0
var duck=0.0
var music: AudioStreamPlayer
var music_volume=.85
var music_players:Array[AudioStreamPlayer]=[]
var music_names=["","","",""]
var music_weights=[0.0,0.0,0.0,0.0]
var music_from_weights=[0.0,0.0,0.0,0.0]
var music_fade_age=0.0
var music_active=0
var music_track=""
var music_bed_db=-4.0
const MUSIC_FADE=2.4

func setup(owner_game) -> void:
	game=owner_game
	var mix_bus=AudioServer.get_bus_index(MIX_BUS)
	if mix_bus<0:
		mix_bus=AudioServer.bus_count;AudioServer.add_bus(mix_bus)
		AudioServer.set_bus_name(mix_bus,MIX_BUS)
		var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-.8;limiter.release=.12
		AudioServer.add_bus_effect(mix_bus,limiter)
	for i in range(8):
		var bus=AudioServer.get_bus_index("Foley"+str(i))
		if bus<0:
			bus=AudioServer.bus_count;AudioServer.add_bus(bus)
			AudioServer.set_bus_name(bus,"Foley"+str(i))
			AudioServer.add_bus_effect(bus,AudioEffectPanner.new())
		AudioServer.set_bus_send(bus,MIX_BUS)
		var pan=AudioServer.get_bus_effect(bus,0) as AudioEffectPanner
		pans.append(pan)
		var p=AudioStreamPlayer.new()
		p.bus="Foley"+str(i)
		if OS.has_feature("web"): p.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		voices.append(p)
	rain=AudioStreamPlayer.new()
	rain.bus=MIX_BUS
	if OS.has_feature("web"): rain.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	rain.stream=load("res://assets/asmr/rain.wav")
	rain.volume_db=-80
	add_child(rain)
	rain.play()
	boil=AudioStreamPlayer.new()
	boil.bus=MIX_BUS
	if OS.has_feature("web"): boil.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	boil.stream=load("res://assets/asmr/boil.wav")
	boil.volume_db=-80
	add_child(boil)
	boil.play()
	for i in range(4):
		var player=AudioStreamPlayer.new()
		player.bus=MIX_BUS
		if OS.has_feature("web"): player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		player.volume_db=-80
		add_child(player);music_players.append(player)
	music=music_players[0]
	change_music("hearth_road")

func desired_music()->String:
	if game.fieldlife and game.fieldlife.hunt.visible:return "hunt_dunes"
	if game.title_screen and game.title_screen.visible:return "hearth_road"
	if game.hour>=19 or game.hour<6:return "camp_lantern"
	if game.hour<14:return "camp_dawn"
	return "hearth_road"

func change_music(track:String):
	if track==music_track:return
	var path="res://assets/asmr/"+track+".ogg"
	if not ResourceLoader.exists(path):return
	var next=music_names.find(track)
	if next<0:
		next=music_names.find("")
		if next<0:return
		music_players[next].stop();music_weights[next]=0.0
		music_players[next].stream=load(path)
		music_players[next].stream.loop=true
		music_names[next]=track
	music_active=next;music_track=track;music=music_players[next]
	music_from_weights=music_weights.duplicate();music_fade_age=0.0
	if not music.playing:music.play()

func play_at(kind: String, pan: float=0, db: float=-10) -> void:
	if game.sound_off: return
	var stream=load("res://assets/asmr/"+kind+".wav")
	if stream==null: return
	var p=voices[next_voice]
	pans[next_voice].pan=pan
	next_voice=(next_voice+1)%voices.size()
	p.stream=stream
	p.volume_db=minf(3.0,db+FOLEY_GAIN_DB)+linear_to_db(maxf(.0001,foley_volume))
	p.pitch_scale=1.0
	p.play()
	duck=1.8

func tick(delta: float) -> void:
	duck=maxf(0,duck-delta)
	var rain_target=-80.0 if game.sound_off or game.rain_amount<.001 else -3.0+linear_to_db(maxf(.0001,ambience_volume*game.rain_amount))-(3 if duck>0 else 0)
	rain.volume_db=move_toward(rain.volume_db,rain_target,delta*32)
	var cooking=game.stage in [1,2,3,4] and game.v4 and game.v4.has_water
	var target_strength=clampf(game.v4.boil_intensity,0,1) if cooking else 0.0
	boil_strength=move_toward(boil_strength,target_strength,delta*.85)
	var boil_target=-80.0 if game.sound_off or not cooking else lerpf(-15.0,-2.0,boil_strength)+linear_to_db(maxf(.0001,foley_volume))
	boil.volume_db=move_toward(boil.volume_db,boil_target,delta*32)
	boil.pitch_scale=lerpf(1.08,.90,boil_strength)
	change_music(desired_music())
	var bed_target=-4.0-(4.0 if duck>0 else 0.0)
	music_bed_db=move_toward(music_bed_db,bed_target,delta*(24.0 if duck>0 else 5.0))
	music_fade_age=minf(MUSIC_FADE,music_fade_age+delta)
	var blend=smoothstep(0.0,MUSIC_FADE,music_fade_age)
	for i in range(music_players.size()):
		music_weights[i]=lerpf(music_from_weights[i],1.0 if i==music_active else 0.0,blend)
		var p=music_players[i]
		p.volume_db=-80.0 if game.sound_off else music_bed_db+linear_to_db(maxf(.0001,music_volume*music_weights[i]))
		if music_weights[i]<=0 and i!=music_active and p.playing:p.stop()
	if game.sound_off:
		for p in music_players:p.volume_db=-80
		rain.volume_db=-80
		boil.volume_db=-80
		for p in voices: p.stop()

func shutdown() -> void:
	for p in voices+[rain,boil]+music_players:
		p.stop()
		p.stream=null
