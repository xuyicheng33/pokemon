extends RefCounted
class_name LifecycleRetentionPolicy

func should_keep_rule_mod_instance(rule_mod_instance, leave_reason: String) -> bool:
	if leave_reason == "faint" or rule_mod_instance == null:
		return false
	return bool(rule_mod_instance.persists_on_switch)
