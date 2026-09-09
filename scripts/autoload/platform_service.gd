extends Node
## Yandex Games adapter. Gameplay code talks only to this service, so the
## desktop/editor build keeps working without the browser SDK.

signal interstitial_finished(was_shown: bool)
signal rewarded_finished(granted: bool)
signal sdk_ready
signal cloud_loaded(data: Dictionary)

const INTERSTITIAL_EVERY_N_TRIPS := 3
const SDK_RETRY_LIMIT := 40
const SDK_RETRY_SECONDS := 0.25

var _initialized: bool = false
var _is_web: bool = false
var _sdk_ready: bool = false
var _player_ready: bool = false
var _cloud_loaded: bool = false
var _cloud_snapshot: Dictionary = {}
var _sdk_attempt: int = 0
var _callback_ref
var _gameplay_active: bool = false
var _resume_after_ad: bool = false
var _active_ad: String = ""
var _rewarded_seen: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	init()

func init() -> void:
	if _initialized:
		return
	_initialized = true
	_is_web = OS.has_feature("web")
	if not _is_web:
		print("[PlatformService] local fallback mode")
		return
	_callback_ref = JavaScriptBridge.create_callback(_on_js_message)
	_try_init_sdk()

func is_ready() -> bool:
	return _initialized

func is_sdk_ready() -> bool:
	return _sdk_ready

func is_ad_active() -> bool:
	return _active_ad != ""

func _try_init_sdk() -> void:
	if _sdk_ready or not _is_web:
		return
	if bool(JavaScriptBridge.eval("typeof YaGames !== 'undefined'")):
		var window = JavaScriptBridge.get_interface("window")
		window.__marsh_godot_callback = _callback_ref
		JavaScriptBridge.eval("""
(async () => {
  try {
    window.__marsh_ysdk = await YaGames.init();
    window.__marsh_ysdk.getPlayer().then((player) => {
      window.__marsh_player = player;
      window.__marsh_godot_callback(JSON.stringify({kind: 'player_ready'}));
      return player.getData();
    }).then((data) => {
      window.__marsh_godot_callback(JSON.stringify({kind: 'cloud_data', data: data || {}}));
    }).catch((error) => {
      console.warn('[Marshrutka] cloud load failed', error);
      window.__marsh_godot_callback(JSON.stringify({kind: 'cloud_data', data: {}}));
    });
    window.__marsh_godot_callback(JSON.stringify({kind: 'sdk_ready'}));
  } catch (error) {
    console.warn('[Marshrutka] Yandex SDK init failed', error);
    window.__marsh_godot_callback(JSON.stringify({kind: 'sdk_failed'}));
  }
})();
""", true)
		return
	_sdk_attempt += 1
	if _sdk_attempt >= SDK_RETRY_LIMIT:
		print("[PlatformService] /sdk.js was not found; using local fallback")
		return
	get_tree().create_timer(SDK_RETRY_SECONDS).timeout.connect(_try_init_sdk)

func _on_js_message(args: Array) -> void:
	if args.is_empty():
		return
	var parsed = JSON.parse_string(String(args[0]))
	if not parsed is Dictionary:
		return
	var packet: Dictionary = parsed
	match String(packet.get("kind", "")):
		"player_ready":
			_player_ready = true
		"sdk_ready":
			_sdk_ready = true
			sdk_ready.emit()
			mark_loading_ready()
		"cloud_data":
			_cloud_loaded = true
			var data = packet.get("data", {})
			if data is Dictionary:
				_cloud_snapshot = data.duplicate(true)
				_apply_cloud_data(_cloud_snapshot)
				cloud_loaded.emit(_cloud_snapshot.duplicate(true))
		"interstitial_close":
			_finish_ad(bool(packet.get("was_shown", false)))
		"interstitial_error":
			_finish_ad(false)
		"rewarded_grant":
			_rewarded_seen = true
		"rewarded_close":
			_finish_ad(bool(packet.get("was_shown", false)) and _rewarded_seen)
		"rewarded_error":
			_finish_ad(false)

func _apply_cloud_data(cloud: Dictionary) -> void:
	if cloud.is_empty() or not SaveManager:
		return
	SaveManager._merge_defaults(SaveManager.data, cloud)
	SaveManager._validate_data()
	SaveManager.save_game()

func maybe_show_interstitial(trips_completed: int) -> void:
	if trips_completed > 0 and trips_completed % INTERSTITIAL_EVERY_N_TRIPS == 0:
		show_interstitial()

func show_interstitial() -> void:
	if _active_ad != "":
		return
	if not _sdk_ready:
		interstitial_finished.emit(false)
		return
	_begin_ad("interstitial")
	JavaScriptBridge.eval("""
if (window.__marsh_ysdk && window.__marsh_ysdk.adv) {
  window.__marsh_ysdk.adv.showFullscreenAdv({
    callbacks: {
      onClose: (wasShown) => window.__marsh_godot_callback(JSON.stringify({kind: 'interstitial_close', was_shown: !!wasShown})),
      onError: () => window.__marsh_godot_callback(JSON.stringify({kind: 'interstitial_error'}))
    }
  });
} else {
  window.__marsh_godot_callback(JSON.stringify({kind: 'interstitial_error'}));
}
""", true)

func show_rewarded(_reward_id: String = "double_reward") -> void:
	if _active_ad != "":
		return
	if not _sdk_ready:
		rewarded_finished.emit(true)
		return
	_rewarded_seen = false
	_begin_ad("rewarded")
	JavaScriptBridge.eval("""
if (window.__marsh_ysdk && window.__marsh_ysdk.adv) {
  window.__marsh_ysdk.adv.showRewardedVideo({
    callbacks: {
      onRewarded: () => window.__marsh_godot_callback(JSON.stringify({kind: 'rewarded_grant'})),
      onClose: (wasShown) => window.__marsh_godot_callback(JSON.stringify({kind: 'rewarded_close', was_shown: !!wasShown})),
      onError: () => window.__marsh_godot_callback(JSON.stringify({kind: 'rewarded_error'}))
    }
  });
} else {
  window.__marsh_godot_callback(JSON.stringify({kind: 'rewarded_error'}));
}
""", true)

func _begin_ad(kind: String) -> void:
	_active_ad = kind
	_resume_after_ad = _gameplay_active
	AudioManager.set_game_paused(true)
	stop_gameplay()

func _finish_ad(was_shown: bool) -> void:
	if _active_ad == "":
		return
	var kind := _active_ad
	_active_ad = ""
	AudioManager.set_game_paused(false)
	if _resume_after_ad:
		start_gameplay()
	_resume_after_ad = false
	if kind == "rewarded":
		rewarded_finished.emit(was_shown)
	else:
		interstitial_finished.emit(was_shown)

func save_cloud(data: Dictionary) -> void:
	if not _player_ready:
		print("[PlatformService] save_cloud() -> local fallback")
		return
	var encoded := JSON.stringify(JSON.stringify(data))
	JavaScriptBridge.eval("""
(async () => {
  try {
    await window.__marsh_player.setData(JSON.parse(%s), true);
  } catch (error) {
    console.warn('[Marshrutka] cloud save failed', error);
  }
})();
""" % encoded, true)

func load_cloud() -> Dictionary:
	if _cloud_loaded:
		return _cloud_snapshot.duplicate(true)
	if SaveManager:
		return SaveManager.data.duplicate(true)
	return {}

func mark_loading_ready() -> void:
	if not _sdk_ready:
		return
	JavaScriptBridge.eval("""
if (window.__marsh_ysdk && window.__marsh_ysdk.features && window.__marsh_ysdk.features.LoadingAPI) {
  window.__marsh_ysdk.features.LoadingAPI.ready();
}
""", true)

func start_gameplay() -> void:
	_gameplay_active = true
	if not _sdk_ready:
		return
	JavaScriptBridge.eval("""
if (window.__marsh_ysdk && window.__marsh_ysdk.features && window.__marsh_ysdk.features.GameplayAPI) {
  window.__marsh_ysdk.features.GameplayAPI.start();
}
""", true)

func stop_gameplay() -> void:
	_gameplay_active = false
	if not _sdk_ready:
		return
	JavaScriptBridge.eval("""
if (window.__marsh_ysdk && window.__marsh_ysdk.features && window.__marsh_ysdk.features.GameplayAPI) {
  window.__marsh_ysdk.features.GameplayAPI.stop();
}
""", true)

func set_leaderboard_score(score: int) -> void:
	if not _sdk_ready:
		print("[PlatformService] leaderboard fallback:", score)
		return
	JavaScriptBridge.eval("""
if (window.__marsh_ysdk && window.__marsh_ysdk.getLeaderboards) {
  window.__marsh_ysdk.getLeaderboards().then((leaderboards) => {
    leaderboards.setLeaderboardScore('main', %d);
  }).catch(() => {});
}
""" % score, true)
