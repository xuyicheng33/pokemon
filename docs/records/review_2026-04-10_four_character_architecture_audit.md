# 2026-04-10 四角色与架构审查记录

## 结论

- 当前项目没有出现“已经跑不动、必须推倒重来”的信号。
- 四个正式角色的关键机制都已经被 formal validator、snapshot suite、runtime suite、manager smoke 和 pair smoke 锁得比较严，当前没有发现角色语义和设计稿明显错位的实现问题。
- 真正的风险不在 battle core 主循环已经失控，而在“正式角色交付链”太重：新增一个复杂角色时，要同时改资源、manifest、baseline descriptor、validator、角色 suite、shared suite 挂载、pair case、设计稿与调整稿。
- 因此不建议彻底重写；建议进入一轮“扩角前定向重构”，重点继续削减角色交付链和共享描述层的维护面，而不是再让新角色按当前模式继续堆。

## 本轮确认的主要风险

### 1. `src/shared/formal_character_baselines/*` 已经成为架构闸门的盲区

- 当前大文件闸门只扫描 `src/battle_core` 与 `src/composition`。
- 但 formal baseline descriptor 已经出现：
  - `src/shared/formal_character_baselines/obito_formal_character_baseline.gd` 291 行
  - `src/shared/formal_character_baselines/kashimo_formal_character_baseline.gd` 256 行
  - `src/shared/formal_character_baselines/gojo_formal_character_baseline.gd` 240 行
- 这些文件虽然主要是字面量 descriptor，不是 runtime owner，但它们已经是正式角色交付链的真实热点；继续扩角时，这里会先失控。

### 2. 正式角色交付面过重，扩角成本已经偏高

- manifest、baseline descriptor、formal validator、角色 suite、shared suite 挂载、pair interaction、设计稿与 adjustment 文档共同形成交付面。
- 当前四个角色都已进入这条链，且复杂角色已经明显拉高维护量：
  - Gojo：21 个角色资源文件
  - Sukuna：17 个角色资源文件
  - Kashimo：20 个角色资源文件
  - Obito：17 个角色资源文件
- 其中 Kashimo 已经是当前最重的样本：
  - validator 7 个文件，共 495 行
  - 角色 suite 9 个文件，共 1037 行
  - 角色 support/helper 3 个文件，共 482 行
- 这条链现在还能靠 gate 压住，但再按同一模式继续扩，会越来越像“改一处，跟着补五六处”。

### 3. composition root 仍然偏字符串驱动

- 服务注册、装配和依赖校验依旧基于 `slot / owner / dependency / source` 这类字符串描述。
- 这套方案当前被 gate 和 `resolve_missing_dependency()` 系列保护住了，但可维护性成本不低；共享机制一旦继续扩，最容易累积的是 wiring 和依赖声明样板。

### 4. 角色文档仍然偏厚，老角色稿还没有完全收口到新模板

- 模板已经明确要求角色稿只保留“角色自己的差异、资源定义、验收矩阵和平衡备注”。
- 但 Gojo / Sukuna / Kashimo 角色稿里仍保留了较多共享机制展开说明。
- 这不是实现错误，但会直接放大后续设计审查和文档同步成本。

## 四角色审查结论

### Gojo

- 关键风险点已经被锁住：
  - `茈` 的双标记、same-owner 和固定 payload 顺序都有 formal validator。
  - `无量空处` 的成功立场后锁行动、field 绑定加成与 break/expire 回收也有 formal validator。
- 当前没有发现需要立刻修改的玩法实现问题。
- 风险主要在于交付面偏重：设计稿、baseline、validator 和 suite 都比较厚。

### Sukuna

- 当前四人里最接近“模板化接入”的角色。
- `灶`、对位回蓝、领域终爆、共享火伤 payload 单源都已被 formal validator 和 manager 黑盒覆盖。
- 没发现当前必须立刻修改的实现问题。

### Kashimo

- 这是当前最值得当作“架构压力测试”的角色。
- 角色本身没有发现明显实现错误；`电荷 / 水中外泄 / 弥虚葛笼 / 幻兽琥珀` 的关键语义都有 formal validator 与公开路径回归。
- 但它已经明显把正式角色交付链推到了高成本区间。若第 5 个角色再比 Kashimo 更复杂，继续沿用现在这套交付方式，维护体验大概率会明显变差。

### Obito

- 新接入角色里，shared mechanism 使用面最广的一位之一：`incoming_heal_final_mod`、`execute_*`、`damage_segments`、`on_receive_action_damage_segment` 都用到了。
- 目前这些共享能力与角色稿、validator、runtime suite 是对齐的，没有发现新引入的角色级破口。
- 说明当前 battle core 的共享扩展点本身还能承载复杂角色，不是已经坏掉的状态。

## 建议

### 不建议

- 不建议现在彻底推倒 battle core 重写。
- 不建议继续按“每来一个新角色，就新增一整串 descriptor + validator + suite + 文档补丁”的原样往前堆。

### 建议的下一步

1. 先做“扩角前定向重构”，不动 battle rules，优先减正式角色交付链的维护面。
2. 把 `src/shared/formal_character_baselines/*` 纳入大文件治理，至少补 gate 或改成更可拆的数据组织方式。
3. 继续压缩角色接入所需的人工维护点，目标是让“资源真相、validator 描述、snapshot descriptor”尽量减少重复录入。
4. 把 `SampleBattleFactory` 和 formal character delivery 周边继续往更数据驱动的方向收，减少新增角色时必须碰到的中心文件。
5. 老角色文档按模板慢慢瘦身，优先删除已经进入共享主线文档的机制展开。

## 验证

- `bash tests/run_with_gate.sh`：通过
- `bash tests/check_architecture_constraints.sh`：通过
- `bash tests/check_repo_consistency.sh`：通过
- `godot --headless --path . --script tests/run_all.gd`：通过
