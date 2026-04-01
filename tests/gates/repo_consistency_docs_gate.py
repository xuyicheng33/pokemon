from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()

ctx.require_contains("docs/design/architecture_overview.md", "get_event_log_snapshot", "architecture facade event log snapshot contract")
ctx.require_contains("docs/design/architecture_overview.md", "{\"ok\": true, \"data\": ... , \"error_code\": null, \"error_message\": null}", "manager envelope doc")
ctx.require_contains("docs/design/battle_content_schema.md", "candidate_skill_ids", "schema candidate skill pool contract")
ctx.require_contains("docs/design/battle_content_schema.md", "regular_skill_loadout_overrides", "schema setup override contract")
ctx.require_contains("docs/design/battle_content_schema.md", "required_target_effects", "schema effect precondition contract")
ctx.require_contains("docs/design/battle_content_schema.md", "required_target_same_owner", "schema effect same-owner precondition contract")
ctx.require_contains("docs/design/battle_content_schema.md", "action_legality", "schema action legality contract")
ctx.require_contains("docs/design/battle_content_schema.md", "incoming_accuracy", "schema incoming accuracy contract")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "220", "architecture early warning threshold")
ctx.require_contains("docs/design/battle_runtime_model.md", "regular_skill_ids", "runtime equipped skill mirror contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "action_legality", "runtime action legality contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "incoming_accuracy", "runtime incoming accuracy contract")
ctx.require_contains("docs/design/command_and_legality.md", "regular_skill_ids", "legality runtime equipped skill contract")
ctx.require_contains("docs/design/command_and_legality.md", "domain_legality_service.gd", "domain legality helper doc")
ctx.require_contains("docs/design/lifecycle_and_replacement.md", "faint_killer_attribution_service.gd", "lifecycle helper doc")
ctx.require_contains("docs/design/lifecycle_and_replacement.md", "faint_leave_replacement_service.gd", "lifecycle replacement helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_context_resolver.gd", "field helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_conflict_service.gd", "field conflict helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_log_service.gd", "field log helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_effect_runner.gd", "field effect runner helper doc")
ctx.require_contains("docs/design/project_folder_structure.md", "facades/", "project folder facades doc")
ctx.require_contains("docs/design/sukuna_design.md", "max_stacks = 3", "sukuna kamado hard cap doc")
ctx.require_contains("docs/design/sukuna_design.md", "不新增第 4 层", "sukuna kamado overflow ignore doc")
ctx.require_contains("docs/design/sukuna_design.md", "max_mp", "sukuna matchup bst max_mp contract")
ctx.require_contains("docs/rules/01_battle_format_and_visibility.md", "candidate_skill_ids", "rules candidate skill pool contract")
ctx.require_contains("docs/rules/01_battle_format_and_visibility.md", "regular_skill_loadout_overrides", "rules setup override contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "required_target_effects", "rules effect precondition contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "required_target_same_owner", "rules effect same-owner precondition contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "action_legality", "rules action legality contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "incoming_accuracy", "rules incoming accuracy contract")
ctx.require_contains("docs/rules/03_stats_resources_and_damage.md", "incoming_accuracy", "rules incoming accuracy read-path")
ctx.require_contains("docs/rules/03_stats_resources_and_damage.md", "max_mp", "rules sukuna matchup bst max_mp contract")
ctx.require_contains("docs/design/domain_field_template.md", "field_apply_success", "domain template success trigger contract")
ctx.require_contains("docs/design/domain_field_template.md", "同回合双方都已排队施放领域时", "domain template dual-domain contract")
ctx.require_contains("docs/rules/05_items_field_input_and_logging.md", "当前正式角色交付面不再包含自动选指策略、自动选指回归或批量模拟案例。", "auto-selection removal rule wording")
ctx.require_contains("docs/records/decisions.md", "固定可复查案例作为角色与规则复查入口", "fixed-case decision wording")
ctx.require_contains("docs/records/decisions.md", "外层输入与公开快照继续只使用 `public_id`。", "public input decision wording")
ctx.require_contains("docs/records/decisions.md", "若未来恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。", "future auto-selection recovery gate")
ctx.require_contains("docs/records/decisions.md", "effect dedupe key 必须包含 effect_instance_id", "effect-instance dedupe decision wording")
ctx.require_contains("docs/records/decisions.md", "field_break / field_expire 链上创建的 successor field 必须保留", "field successor cleanup decision wording")
ctx.require_contains("docs/records/decisions.md", "正式角色注册表当前必须登记角色 effect 资源、wrapper 下属 suite 与关键回归测试名", "formal registry expansion decision wording")
ctx.require_contains("docs/records/decisions.md", "BattleCoreManager` 公开 contract 统一为严格 envelope", "manager envelope decision wording")
ctx.require_contains("docs/records/decisions.md", "宿傩“灶”正式写死为 3 层硬上限，满层后忽略新层", "sukuna kamado cap decision wording")
ctx.require_contains("docs/records/decisions.md", "运行时 helper 全部统一进 composition 装配", "runtime helper composition decision wording")
ctx.require_contains("docs/records/decisions.md", "suite 可达性闸门", "suite reachability decision wording")
ctx.require_contains("tests/check_architecture_constraints.sh", "ARCH_GATE_WARNING", "architecture warning marker")

stale_candidate_wording = [
    "schema 暂不扩候选技能池字段",
    "当前 schema 不单独编码",
    "写死在 README 与内容说明文档里",
]
for rel_path in [
    "README.md",
    "content/README.md",
    "docs/design/battle_content_schema.md",
    "docs/records/decisions.md",
]:
    for needle in stale_candidate_wording:
        ctx.require_absent(rel_path, needle, "candidate skill pool drift wording")

domain_matrix_redundant_wording = [
    "比较双方**扣费后的当前 MP**；MP 高者留场；平 MP 随机决定胜者",
    "比较双方扣费后的当前 MP；高者留场；平 MP 随机决定胜者",
]
for rel_path in [
    "docs/design/gojo_satoru_design.md",
    "docs/design/sukuna_design.md",
]:
    for needle in domain_matrix_redundant_wording:
        ctx.require_absent(rel_path, needle, "role design duplicated public domain matrix wording")

ctx.finish("design/rules/decisions wording and stale phrasing are aligned")
