# 本地化检查与复核边界

英文 ARB 是消息模板。英文、简体中文和繁体中文提供全部消息；其他语言的已知缺译通过 [allowedFallbacks](../tool/l10n/translation_policy.dart) 明确登记。缺译时移除该语言中复制的英文值，由 `flutter gen-l10n` 使用当前英文模板生成回退，避免英文更新后还显示旧句子。补译后添加相应 ARB 消息并更新登记。

当前共用回退包含助手预览说明和此前登记的新功能消息；荷兰语另有 10 条导入、导出与隐私入口说明采用当前英文。这里记录的是内容来源与待补译范围，不表示这些语言完成了母语复核，也不改变语言选择器的覆盖范围。

运行 `flutter gen-l10n` 后，用以下检查确认消息与生成结果一致：

```powershell
flutter test --no-pub test/l10n_completeness_test.dart test/l10n_english_fallback_test.dart
```

键齐全、英文回退与自动检查通过，只能证明结构和已登记规则成立。语言自然度、术语、称谓和隐私说明的准确表达仍需要对应语言的人工复核。
