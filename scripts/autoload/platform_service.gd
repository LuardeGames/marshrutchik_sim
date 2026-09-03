extends Node
## Adapter layer for platform SDK integration (Yandex Games and others).
## Gameplay code never talks to JS/Yandex directly - only to this service.
## All methods currently fall back to local no-op / local-storage behaviour
## and can be swapped for real SDK calls (via JavaScriptBridge) later
## without touching gameplay code.

signal interstitial_finished
signal rewarded_finished(granted: bool)

var _initialized: bool = false
var _is_web: bool = false
var _interstitial_count: int = 0
const INTERSTITIAL_EVERY_N_TRIPS := 3

func init() -> void:
	_is_web = OS.has_feature("web")
	_initialized = true
	print("[PlatformService] init() - web:", _is_web, " (local fallback mode)")

func is_ready() -> bool:
	return _initialized

## Call after a trip completes. Decides internally whether to actually show
## an interstitial (not spammed on every trip).
func maybe_show_interstitial(trips_completed: int) -> void:
	if trips_completed <= 0 or trips_completed % INTERSTITIAL_EVERY_N_TRIPS != 0:
		return
	show_interstitial()

func show_interstitial() -> void:
	_interstitial_count += 1
	print("[PlatformService] show_interstitial() (mock) #", _interstitial_count)
	# Real integration point (Yandex): JavaScriptBridge.eval("ysdk.adv.showFullscreenAdv(...)")
	interstitial_finished.emit()

func show_rewarded(reward_id: String = "double_reward") -> void:
	print("[PlatformService] show_rewarded() (mock) reward:", reward_id)
	# Real integration point (Yandex): ysdk.adv.showRewardedVideo({ callbacks })
	# Local fallback: always grant the reward instantly.
	rewarded_finished.emit(true)

func save_cloud(data: Dictionary) -> void:
	print("[PlatformService] save_cloud() -> local fallback (SaveManager)")
	# Real integration point: player.setData(data)
	if SaveManager:
		SaveManager._merge_defaults(SaveManager.data, data)
		SaveManager.save_game()

func load_cloud() -> Dictionary:
	print("[PlatformService] load_cloud() -> local fallback (SaveManager)")
	# Real integration point: player.getData()
	if SaveManager:
		return SaveManager.data.duplicate(true)
	return {}

func set_leaderboard_score(score: int) -> void:
	print("[PlatformService] set_leaderboard_score() (mock):", score)
	# Real integration point: lb.setLeaderboardScore('main', score)
