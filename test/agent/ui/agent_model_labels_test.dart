import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/ui/agent_model_labels.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';

void main() {
  test(
    'reasoning tier names stay English in every offered interface language',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        expect(
          AgentReasoningEffort.values.map(
            (effort) => agentReasoningEffortLabel(l, effort),
          ),
          ['None', 'Minimal', 'Low', 'Medium', 'High', 'XHigh', 'Max'],
          reason: locale.toLanguageTag(),
        );
      }
    },
  );
}
