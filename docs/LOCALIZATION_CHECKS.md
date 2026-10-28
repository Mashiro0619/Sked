# 本地化检查与复核边界

各语言的资源数量、英文回退和人工验收记录见 [语言状态](LOCALIZATION_STATUS.md)。该记录按源码快照更新，不把自动检查结果当作母语复核结论。

英文 ARB 是消息模板。英文、简体中文和繁体中文提供全部消息；其他语言的已知缺译通过 [allowedFallbacks](../tool/l10n/translation_policy.dart) 明确登记。缺译时移除该语言中复制的英文值，由 `flutter gen-l10n` 使用当前英文模板生成回退，避免英文更新后还显示旧句子。补译后添加相应 ARB 消息并更新登记。

当前共用回退包含助手预览说明和此前登记的新功能消息；荷兰语另有 10 条导入、导出与隐私入口说明采用当前英文。这里记录的是内容来源与待补译范围，不表示这些语言完成了母语复核，也不改变语言选择器的覆盖范围。

运行 `flutter gen-l10n` 后，用以下检查确认消息与生成结果一致：

```powershell
dart tool/l10n/check.dart --json
flutter test --no-pub test/l10n_completeness_test.dart test/l10n_english_fallback_test.dart test/l10n_count_phrases_test.dart test/tool/l10n_audit_test.dart
```

键齐全、英文回退与自动检查通过，只能证明结构和已登记规则成立。语言自然度、术语、称谓和隐私说明的准确表达仍需要对应语言的人工复核。

## 持续审计

[共享审计](../tool/l10n/arb_audit.dart) 由原有完整性测试调用，随完整 VM 测试进入 CI；命令行入口使用相同规则，可用 `--arb-dir` 检查另一份 ARB 目录。默认检查仓库资源，`--json` 输出机器可读结果，不写入文件；通过返回 0，内容错误返回 1，参数错误返回 64。

检查内容包括：26 种已提供语言的文件是否齐全、JSON 对象是否合法、消息键是否遗漏或多写、消息是否为空，以及回退登记是否引用真实模板键。已核实的旧英文按消息键与原文登记，忽略空白和大小写差异后检查；不会凭拉丁字母猜测语言，也不会把 Sked、Google Play 或共享词当成错误。显式回退键如果又复制了当前英文，会要求移除该副本，使未来英文修改自动生效；实际补上的译文仍可通过。

新增或修改英文回退时更新登记；发现其他旧英文时，先核实其来源和当前含义，再补入旧值清单和回归。未登记的旧英文、语义偏差与自然度仍需人工复核。JSON 报告中的缺译数量表示已登记的资源缺失，不是翻译质量得分；计数短语使用真实生成类测试，合法的同形类别和“标签：数字”不被机械拒绝。ICU 语法及占位符仍由 `flutter gen-l10n` 的既有生成门禁验证，文案是否超出控件由相应布局测试验证。

## 计数短语

计数检查运行 [实际生成的文案](../test/l10n_count_phrases_test.dart)，而不只计算 ARB 中出现了几个复数类别。`one` 不总是数字 1：俄语 21 和斯洛文尼亚语 101 也会进入该类别；法语等语言的 0 也可能进入。分支应保留传入数字，不能把这些计数固定输出成 1。所有语言的节次数量都检查数字是否原样保留。

已确认的天数名词短语按 CLDR 46 词形验证：罗马尼亚语 20 为 `20 de zile`，斯洛文尼亚语 101 为 `101 dan`，俄语 21 为 `21 день`，并覆盖邻近计数和重复类别。斯洛文尼亚语的 `few` 与 `other` 均使用 `dni`，有效回退无需为了类别数量再复制一个同形分支。`标签：数字`、裸数字及不随计数变化的词不强制增加复数分支。

资料来源：[CLDR 46 复数规则](https://github.com/unicode-org/cldr/blob/release-46/common/supplemental/plurals.xml)、CLDR 46.0.0 日单位词形（[罗马尼亚语](https://github.com/unicode-org/cldr-json/blob/46.0.0/cldr-json/cldr-units-full/main/ro/units.json)、[斯洛文尼亚语](https://github.com/unicode-org/cldr-json/blob/46.0.0/cldr-json/cldr-units-full/main/sl/units.json)、[俄语](https://github.com/unicode-org/cldr-json/blob/46.0.0/cldr-json/cldr-units-full/main/ru/units.json)）。这是明确句式与代表计数的检查，不代表所有翻译都经过语法或母语复核。
