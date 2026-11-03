# 蘇清的模组与补丁仓库 | SuQing’s Mod and Patch Repositories

截至2026-11-03，**42 个独立 Mod ID** 分布在 **9 个主模组仓库和 1 个含33项补丁的源码合集仓库，共10个仓库**。来源组织不改变游戏内Mod ID、依赖或加载顺序。
As of 2026-11-03, **42 independent Mod IDs** are organized in **nine main-mod repositories and one 33-patch source repository: ten repositories in total**. Source organization does not change in-game IDs, dependencies or load order.

## 源码范围与个人安装状态 | Source scope and personal deployment

2026-11-03用户已授权本轮统一Git与Steam更新，不再等待音乐实测后才整理源码或发布。音乐专辑与饵托量产仍按最新说明列为尚待游戏内验收；负重训练个人0.3.1获用户正常反馈，0.3.2的新美术尚待游戏内视觉验收。源码、上传及公开状态均不代替玩法验收。
The user authorized this unified Git/Steam update on 2026-11-03. Source and publication work no longer waits for music gameplay acceptance. Music Albums and Chum Mass Production still await in-game acceptance under the latest instruction. Personal Weight Training 0.3.1 was reported normal; the new artwork in source 0.3.2 awaits in-game visual acceptance. Source/upload/publication status is separate from gameplay acceptance.

表中分别记录源码版本和个人安装版本。正常实现所需效果的个人组合可保留：普通容器1.0.0继续配现有穿戴桥接，灌溉个人0.3.2-rc.1与源码1.0.0分别记录；不为版本一致而覆盖运行目录。库存转移1.2.1和PZO汉化1.1.0源码已同步已部署文件。
Source and personal versions are separate columns. Working personal combinations may remain unchanged: ordinary containers retain 1.0.0 plus the existing wearable bridge, and personal irrigation 0.3.2-rc.1 is recorded separately from source 1.0.0. No runtime replacement is implied by version parity. Inventory Transfer 1.2.1 and PZO translation 1.1.0 sources match the deployed files.

补丁源码合集33项的工坊分包为25个合集可选子模组、3个EX同包配套子模组及5个暂缓公开的上游完整输出案例。九个主模组分别发布。音乐、负重和25项合集已于11月3日提交成功并公开查询核验；其余7个既有模组条目已查询确认保持公开且内容元数据未变。没有重新下载远端逐文件核对，也不将发布核验当作游戏验收。
The 33 source patches are distributed as 25 optional collection submods, three EX-package companions and five held upstream-payload cases. Nine main mods have their own items. Music, Weight Training and the 25-entry collection passed native submission and public-query verification on November 3. The other seven existing mod items were queried public and unchanged. This is not a remote per-file download or gameplay acceptance.

| 仓库 / Repository | 中英名称 / Bilingual title | Mod ID 数 / Count |
| --- | --- | ---: |
| [suqing-container-upgrade](https://github.com/suching8848/suqing-container-upgrade) | 蘇清的容器升级模组 / SuQing’s Container Upgrades Mod | 1 |
| [suqing-modern-firearms-weight-charms](https://github.com/suching8848/suqing-modern-firearms-weight-charms) | 蘇清的现代枪械减重挂件模组 / SuQing’s Firearm Weight Charms Mod | 1 |
| [suqing-backpack-super-upgrade](https://github.com/suching8848/suqing-backpack-super-upgrade) | 蘇清的背包超级升级模组 / SuQing’s Backpack Super Upgrades Mod | 1 |
| [suqing-refrigeration-upgrade](https://github.com/suching8848/suqing-refrigeration-upgrade) | 蘇清的冷藏升级模组 / SuQing’s Refrigeration Upgrades Mod | 1 |
| [suqing-sprinkler-fertilizer](https://github.com/suching8848/suqing-sprinkler-fertilizer) | 蘇清的灌溉养护模组 / SuQing’s Irrigation Care Mod | 1 |
| [suqing-mfs-fixed-buyback](https://github.com/suching8848/suqing-mfs-fixed-buyback) | 蘇清的枪械商店固定收购模组 / SuQing’s MFS Fixed Buyback Mod | 1 |
| [suqing-container-auto-upgrade](https://github.com/suching8848/suqing-container-auto-upgrade) | 蘇清的容器自动识别升级模组（实验版） / SuQing’s Automatic Container Upgrades Mod — Experimental | 1 |
| [suqing-music-albums](https://github.com/suching8848/suqing-music-albums) | 蘇清的音乐专辑 / SuQing’s Music Albums | 1 |
| [suqing-weight-training](https://github.com/suching8848/suqing-weight-training) | 蘇清的负重训练 / SuQing’s Weight Training | 1 |
| [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) | 蘇清的僵尸毁灭工程补丁合集 / SuQing’s Project Zomboid Patch Collection | 33 |

主模组按功能选择前置及配套补丁；补丁保持独立Mod ID，不能全选、自动重排或忽略外部原作依赖。
Choose prerequisites and companion patches for the actual feature. Patches keep independent IDs; do not enable the whole collection, reorder unrelated entries or omit external originals.

## 42 项源码索引 | Index of All 42 Mod IDs

[机器可读索引 / Machine-readable index](project-index.json)

| Mod ID | 中英名称 / Bilingual title | 源码版本 / Source | 个人版本 / Personal | Git 仓库 / Repository |
| --- | --- | --- | --- | --- |
| `SuQingContainerUpgrade_4221` | 蘇清的容器升级模组 / SuQing’s Container Upgrades Mod | `1.0.1` | `1.0.0` | [suqing-container-upgrade](https://github.com/suching8848/suqing-container-upgrade) |
| `Codex_PetGunWeightKits_4221` | 蘇清的现代枪械减重挂件模组 / SuQing’s Firearm Weight Charms Mod | `1.2.1` | `1.2.1` | [suqing-modern-firearms-weight-charms](https://github.com/suching8848/suqing-modern-firearms-weight-charms) |
| `ExSuQingBackpackSuperUpgrade_4221` | 蘇清的背包超级升级模组 / SuQing’s Backpack Super Upgrades Mod | `1.0.0-rc.2` | `1.0.0-rc.2` | [suqing-backpack-super-upgrade](https://github.com/suching8848/suqing-backpack-super-upgrade) |
| `SuQingRefrigerationUpgrade_4221` | 蘇清的冷藏升级模组 / SuQing’s Refrigeration Upgrades Mod | `1.0.0-rc.2-perf.1` | `1.0.0-rc.2-perf.1` | [suqing-refrigeration-upgrade](https://github.com/suching8848/suqing-refrigeration-upgrade) |
| `SuQingSprinklerFertilizer` | 蘇清的灌溉养护模组 / SuQing’s Irrigation Care Mod | `1.0.0` | `0.3.2-rc.1` | [suqing-sprinkler-fertilizer](https://github.com/suching8848/suqing-sprinkler-fertilizer) |
| `SuQingMFSFixedBuyback_4221` | 蘇清的枪械商店固定收购模组 / SuQing’s MFS Fixed Buyback Mod | `1.1.0` | `1.1.0` | [suqing-mfs-fixed-buyback](https://github.com/suching8848/suqing-mfs-fixed-buyback) |
| `SuQingContainerUpgradeAuto_4221` | 蘇清的容器自动识别升级模组（实验版） / SuQing’s Automatic Container Upgrades Mod — Experimental | `0.1.0-test` | `0.1.0-test` | [suqing-container-auto-upgrade](https://github.com/suching8848/suqing-container-auto-upgrade) |
| `SuQingMusicCollections` | 蘇清的音乐专辑 / SuQing’s Music Albums | `1.1.0` | `1.1.0` | [suqing-music-albums](https://github.com/suching8848/suqing-music-albums) |
| `SuQingWeightTraining` | 蘇清的负重训练 / SuQing’s Weight Training | `0.3.2` | `0.3.1` | [suqing-weight-training](https://github.com/suching8848/suqing-weight-training) |
| `Codex_AmmoBox_CN_TextFix_4221` | 蘇清的洗衣皂中文文本修复补丁 / SuQing’s Washing Soap Chinese Text Fix Patch | `1.2.0` | `1.2.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_AttachedGrouping_4221` | 蘇清的挂点物品分组与穿戴菜单修复补丁 / SuQing’s Attached Item Grouping and Wear Menu Fix Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_Campers_Glovebox_4221` | 蘇清的房车手套箱容器兼容补丁 / SuQing’s Campers Glovebox Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_ChineseCrop_Tooltip_4221` | 蘇清的中华菜与N&C种子提示兼容补丁 / SuQing’s Chinese Cuisine and N&C Seed Tooltips Patch | `1.1` | `1.1` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_FashionoidFluidTooltip_4221` | 蘇清的Fashionoid储液提示兼容补丁 / SuQing’s Fashionoid Fluid Tooltip Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_MFSOpticsFix_4221` | 蘇清的MFS瞄具标签修复补丁 / SuQing’s MFS Optics Tag Fix Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_MustangRecipeGuard_4221` | 蘇清的Mustang引擎盖配方输入保护补丁 / SuQing’s Mustang Hood Recipe Guard Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_NarcoticsStatus_4221` | 蘇清的N&C药物状态面板补丁 / SuQing’s N&C Drug Status Panel Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_StimCompatibility_4221` | 蘇清的针剂减重与肾上腺素笔兼容补丁 / SuQing’s Stim Weight and Adrenapen Compatibility Patch | `1.0.1` | `1.0.1` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_SuQingWearableCompat_4221` | 蘇清的旧普通容器桥接与HavenFall EX兼容补丁 / SuQing’s Legacy Container Bridge and HavenFall EX Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_XFDynamicRecordGuard_4221` | 蘇清的XFACTION进度记录保护补丁 / SuQing’s XFACTION Progress Record Guard Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexCBRTIndependent_4221` | 蘇清的Chemical独立兼容构建补丁 / SuQing’s Chemical Independent Compatibility Build Patch | `1.0.0-local` | `1.0.0-local` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexCharacterMenuTweaks_4221` | 蘇清的人物菜单调整补丁 / SuQing’s Character Menu Tweaks Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexNarcotics_CN_4221` | 蘇清的N&C中文补丁 / SuQing’s N&C Chinese Translation Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexNekomataEXCompat_4221` | 蘇清的猫又岭与EX兼容桥接补丁 / SuQing’s Nekomata Ridge and EX Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexNekomataEXUpgrade_4221` | 蘇清的猫猫背包EX升级扩展补丁 / SuQing’s Nekomata Backpack EX Upgrade Extension Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexPZOptimization_CN_4221` | 蘇清的PZ Optimization设置汉化补丁 / SuQing’s PZ Optimization Chinese Settings Patch | `1.1.0` | `1.1.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexTranslatorPercentFix_4221` | 蘇清的True 3D Items百分号提示修复补丁 / SuQing’s True 3D Items Percent Tooltip Fix Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `CodexXFACTION_CN_4221` | 蘇清的XFACTION动态特性汉化补丁 / SuQing’s XFACTION Dynamic Traits Chinese Translation Patch | `1.0.1` | `1.0.1` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_DAMN_VanillaTires_4221` | 蘇清的DAMN原版轮胎维修兼容补丁 / SuQing’s DAMN Vanilla Tire Repair Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_DebugMenu_Generator_4221` | 蘇清的Erika家具与可选调试生成器修复补丁 / SuQing’s Erika Furniture and Optional Debug Generator Fix Patch | `1.2.0` | `1.2.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_InventoryTransferPerformance_4221` | 蘇清的批量转移库存刷新优化补丁 / SuQing’s Bulk Transfer Inventory Refresh Optimization Patch | `1.2.1` | `1.2.1` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_MFS_AmmoVisual_Compat_4221` | 蘇清的MFS弹药盒与弹匣显示兼容补丁 / SuQing’s MFS Ammo Box and Magazine Visual Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_MFS_AttachedLight_Hotkey_4221` | 蘇清的MFS附加手电快捷键修复补丁 / SuQing’s MFS Attached Flashlight Hotkey Fix Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_NoirSling_SP_Compat_4221` | 蘇清的Noir枪带单人兼容补丁 / SuQing’s Noir Sling Single-player Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `PinyinSearch_SafeSources_4221_LocalFix` | 蘇清的拼音搜索与界面兼容补丁 / SuQing’s Pinyin Search UI Compatibility Patch | `1.1` | `1.1` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_PrimitiveTooltip_4221` | 蘇清的原始装备储液提示修复补丁 / SuQing’s Primitive Equipment Fluid Tooltip Fix Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `SuQingBatchFarmingMenu_4221` | 蘇清的批量农耕菜单筛选补丁 / SuQing’s Batch Farming Menu Filter Patch | `0.1.0` | `0.1.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_TheyKnew_CN_TextFix_4221` | 蘇清的They Knew沙盒文本修复补丁 / SuQing’s They Knew Sandbox Text Fix Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `Codex_TrueMusic_Headphones_4221` | 蘇清的True Music耳机单人兼容补丁 / SuQing’s True Music Headphones Single-player Compatibility Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `SuQingProteinTrainingBoost` | 蘇清的蛋白饮料训练强化 / SuQing's Protein Shake Training Boost | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `SuQingRecipeInputGuard_4221` | 蘇清的配方材料输入修复 / SuQing's Recipe Input Guard | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |
| `SuQingChumMassProduction` | 蘇清的饵托量产补丁 / SuQing’s Chum Mass Production Patch | `1.0.0` | `1.0.0` | [suqing-project-zomboid-patches](https://github.com/suching8848/suqing-project-zomboid-patches) |

版本和数量属于本页生成时快照。JSON保留实际mod.info相对路径、require/loadModAfter和分包状态；后续使用前复核实际文件。历史启用快照不是当前启用名单，也不证明每个项目或组合通过游戏内验收。
Versions and counts are generation-time snapshots. The JSON retains repository-relative mod.info paths, literal requirements/load hints and distribution status. Recheck actual files before acting. Historical enabled snapshots are not current enabled lists or proof that every mod/combination passed in-game acceptance.
