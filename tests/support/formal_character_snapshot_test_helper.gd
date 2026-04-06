extends RefCounted
class_name FormalCharacterSnapshotTestHelper

func build_content_index(harness):
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return null
	return harness.build_loaded_content_index(sample_factory)

func build_content_index_for_setup(harness, battle_setup):
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return null
	return harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)

func run_checks(harness, checks: Array[Dictionary]) -> Dictionary:
	var failures: Array[String] = []
	for check in checks:
		if check["actual"] != check["expected"]:
			failures.append("%s expected=%s actual=%s" % [
				String(check["label"]),
				var_to_str(check["expected"]),
				var_to_str(check["actual"]),
			])
	if not failures.is_empty():
		return harness.fail_result("\n".join(failures))
	return harness.pass_result()
