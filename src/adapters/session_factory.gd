extends RefCounted
class_name SessionFactory

## battle runtime 装配的统一入口。
##
## 把 `BattleCoreComposer.new() + compose_manager() + SampleBattleFactory.new()`
## 这条 4 行 boilerplate 抽出，让 adapter 层（player_battle_session /
## sandbox_session_bootstrap_service）不再各自 preload composer 与 sample
## factory；adapter 只持 manager / sample_factory 两个真正使用的句柄。
## 失败路径：返回 envelope `{ok, manager, sample_factory, composer,
## error_message}`，调用方按需读 manager + sample_factory，错误信息直接透传。
##
## 释放：典型用法是把 `composer` 与 `manager + sample_factory` 都存进 state，
## dispose 时统一调 `dispose_battle_runtime` 释放 manager + sample_factory，
## composer 是 RefCounted 一次性对象、随作用域结束被自动回收，不必显式 dispose。

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory.gd")


static func compose_battle_runtime() -> Dictionary:
	var composer = BattleCoreComposerScript.new()
	if composer == null:
		return {
			"ok": false,
			"manager": null,
			"sample_factory": null,
			"composer": null,
			"error_message": "SessionFactory failed to construct composer",
		}
	var manager = composer.compose_manager()
	if manager == null:
		var composer_error: Dictionary = composer.error_state()
		return {
			"ok": false,
			"manager": null,
			"sample_factory": null,
			"composer": composer,
			"error_message": "SessionFactory failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error")),
		}
	var sample_factory = SampleBattleFactoryScript.new()
	if sample_factory == null:
		return {
			"ok": false,
			"manager": manager,
			"sample_factory": null,
			"composer": composer,
			"error_message": "SessionFactory failed to construct sample battle factory",
		}
	return {
		"ok": true,
		"manager": manager,
		"sample_factory": sample_factory,
		"composer": composer,
		"error_message": "",
	}


static func dispose_battle_runtime(manager, sample_factory) -> void:
	if manager != null and manager.has_method("dispose"):
		manager.dispose()
	if sample_factory != null and sample_factory.has_method("dispose"):
		sample_factory.dispose()
