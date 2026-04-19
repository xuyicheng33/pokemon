extends RefCounted
class_name BattleInitializerPorts

var id_factory: IdFactory = null
var rng_service: RngService = null
var faint_resolver: FaintResolver = null
var trigger_batch_runner: TriggerBatchRunner = null
var battle_logger: BattleLogger = null
var log_event_builder: LogEventBuilder = null
var combat_type_service: CombatTypeService = null
var mp_service: MpService = null
var rule_mod_service: RuleModService = null
var battle_result_service: BattleResultService = null
var field_lifecycle_service: TurnFieldLifecycleService = null
