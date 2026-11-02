import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Plain Agent text that retains selection and a native Windows readable name.
class AgentSelectableText extends StatelessWidget {
  const AgentSelectableText(this.data, {super.key, this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = SelectableText(data, style: style);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return text;
    // The Windows bridge names readonly static text from its label, not value.
    // Merge the label without excluding the child's selection/copy semantics.
    return Semantics(label: data, child: text);
  }
}
