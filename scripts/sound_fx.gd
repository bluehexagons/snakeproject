extends Node

enum Cue { PICKUP, BODY_TAP, ROCK_TAP, SHATTER, WARNING, LOSS, UI }

const SAMPLE_RATE = 32000
const IMPACT_VOICES = 3
const CUE_VOICES = 7
const VOICE_GAIN = 0.11
const MIN_IMPACT_IMPULSE = 0.72
const CONTACT_COOLDOWN_FRAMES = 9
const PICKUP_SCALE = [0, 2, 4, 7, 9]

var _clips: Dictionary[Cue, AudioStreamWAV]
var _impact_voices: Array[AudioStreamPlayer] = []
var _cue_voices: Array[AudioStreamPlayer] = []
var _recent_impacts: Dictionary[String, int]
var _prune_at_frame: int = 0
var _last_pickup_frame: int = -1
var _pending_impact_strength: float = 0.0
var _pending_impact_cue: Cue = Cue.BODY_TAP
var _random = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	# Cache PCM clips so impacts only need to schedule a voice during play.
	_clips = {
		Cue.PICKUP: _chime([523.25, 783.99], 0.36, 0.9, 0.045),
		Cue.BODY_TAP: _chime([440.0], 0.18, 0.72),
		Cue.ROCK_TAP: _chime([261.63], 0.25, 0.96),
		Cue.SHATTER: _chime([392.0, 587.33, 1046.5], 0.47, 1.4, 0.024),
		Cue.WARNING: _chime([659.25, 622.25], 0.32, 0.52, 0.095),
		Cue.LOSS: _chime([659.25, 523.25, 349.23], 0.73, 0.86, 0.108),
		Cue.UI: _chime([880.0], 0.135, 0.45),
	}
	_impact_voices = _make_voices(IMPACT_VOICES)
	_cue_voices = _make_voices(CUE_VOICES)

func _make_voices(count: int) -> Array[AudioStreamPlayer]:
	var voices: Array[AudioStreamPlayer] = []
	for index in count:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	return voices

func play(cue: Cue, gain: float = 1.0, pitch_scale: float = 1.0) -> void:
	if gain <= 0.0:
		return
	var voices := _impact_voices if cue in [Cue.BODY_TAP, Cue.ROCK_TAP] else _cue_voices
	var voice := voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice.playing and cue not in [Cue.LOSS, Cue.SHATTER]:
		return
	voice.stream = _clips[cue]
	voice.volume_linear = clampf(gain, 0.0, 1.0) * VOICE_GAIN
	voice.pitch_scale = clampf(pitch_scale, 0.55, 1.8)
	voice.play()

func pickup(total_eaten: int) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _last_pickup_frame:
		return
	_last_pickup_frame = frame
	var semitones: int = PICKUP_SCALE[posmod(total_eaten - 1, PICKUP_SCALE.size())]
	play(Cue.PICKUP, 0.88, pow(2.0, semitones / 12.0))

func queue_impact(body: Node, other: Node, impulse: float) -> void:
	var barrier := other.is_in_group("barrier")
	var dynamic := other.is_in_group("physics_object")
	var minimum := MIN_IMPACT_IMPULSE if dynamic or barrier else 1.50
	if impulse <= minimum:
		return
	var frame := Engine.get_physics_frames()
	var a := body.get_instance_id()
	var b := other.get_instance_id()
	var pair := "%d/%d" % [mini(a, b), maxi(a, b)]
	if frame < _recent_impacts.get(pair, 0):
		return
	_recent_impacts[pair] = frame + CONTACT_COOLDOWN_FRAMES

	var intensity := smoothstep(minimum, 5.0, impulse)
	var strength := lerpf(0.13, 0.94, sqrt(intensity))
	if not dynamic and not barrier:
		strength *= 0.56
	# Both bodies report the same contact. Keep one cue per pair and favor the
	# loudest new hit when several contacts arrive in the same render frame.
	if strength > _pending_impact_strength:
		_pending_impact_strength = strength
		var hard_surface := barrier or body.is_in_group("rock") or other.is_in_group("rock")
		_pending_impact_cue = Cue.ROCK_TAP if hard_surface else Cue.BODY_TAP

func _process(_delta: float) -> void:
	if _pending_impact_strength > 0.0:
		var pitch := lerpf(1.24, 0.79, _pending_impact_strength) * _random.randf_range(0.96, 1.04)
		play(_pending_impact_cue, _pending_impact_strength, pitch)
		_pending_impact_strength = 0.0

	var frame := Engine.get_physics_frames()
	if frame >= _prune_at_frame:
		for pair in _recent_impacts.keys():
			if _recent_impacts[pair] <= frame:
				_recent_impacts.erase(pair)
		_prune_at_frame = frame + 60

static func _chime(notes: PackedFloat32Array, duration: float, brightness: float, spacing: float = 0.0) -> AudioStreamWAV:
	var frames := roundi(SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	var note_gain := 0.85 / sqrt(notes.size())
	for frame in frames:
		var time := float(frame) / SAMPLE_RATE
		var value := 0.0
		for index in notes.size():
			var age := time - spacing * index
			if age <= 0.0:
				break
			var phase := TAU * notes[index] * age
			var body := sin(phase) * exp(-age * 5.0 / duration) + 0.23 * sin(phase * 2.01) * exp(-age * 25.0)
			# Inharmonic partials die out quickly, leaving a tuned bell tone.
			var glass := 0.43 * sin(phase * 2.76) * exp(-age * 42.0) + 0.19 * sin(phase * 5.41) * exp(-age * 72.0)
			value += (body + brightness * glass) * smoothstep(0.0, 0.004, age)
		var tail := smoothstep(0.0, 0.035, duration - time)
		samples.encode_s16(frame * 2, roundi(tanh(value * note_gain) * tail * 32767.0))

	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = SAMPLE_RATE
	clip.data = samples
	return clip
