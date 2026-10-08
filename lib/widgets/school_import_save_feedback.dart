import 'package:material_ui/material_ui.dart';

import '../data/timetable_storage.dart';
import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';

bool canSaveSchoolImport(TimetableProvider? provider) =>
    provider == null ||
    (provider.canWrite &&
        !provider.isRestoringAppBackup &&
        !provider.isDataClearActive &&
        provider.isWorkspaceEnabled(AppMode.student));

String? schoolImportSaveBlockedMessage(
  TimetableProvider? provider,
  AppLocalizations l10n,
) {
  if (provider == null) return null;
  if (provider.isRestoringAppBackup) return l10n.backupRestoreInProgressMessage;
  if (provider.isStorageWriteStateUnknown) {
    return l10n.dataRecoveryWriteStateUnknownMessage;
  }
  if (!provider.canWrite) {
    return switch (provider.storageLoadStatus) {
      StorageLoadStatus.corrupt => l10n.dataRecoveryCorruptMessage,
      StorageLoadStatus.unsupportedVersion =>
        l10n.dataRecoveryUnsupportedVersionMessage,
      _ => l10n.dataRecoveryIoFailureMessage,
    };
  }
  return provider.isDataClearActive ? l10n.saveFailedRetry : null;
}

String mapSchoolImportApplyError(Object error, AppLocalizations l10n) {
  if (error is AppBackupRestoreInProgressException) {
    return l10n.backupRestoreInProgressMessage;
  }
  if (error is FormatException) return error.message;
  return l10n.saveFailedRetry;
}

class SchoolImportSaveFeedback extends StatefulWidget {
  const SchoolImportSaveFeedback({
    super.key,
    this.provider,
    this.isSaving = false,
    this.error,
    this.onRecoveryBusyChanged,
  });

  final TimetableProvider? provider;
  final bool isSaving;
  final Object? error;
  final ValueChanged<bool>? onRecoveryBusyChanged;

  @override
  State<SchoolImportSaveFeedback> createState() =>
      _SchoolImportSaveFeedbackState();
}

class _SchoolImportSaveFeedbackState extends State<SchoolImportSaveFeedback> {
  bool _retrying = false;
  Object? _retryError;

  Future<void> _retryStorageLoad() async {
    final provider = widget.provider;
    if (provider == null ||
        widget.isSaving ||
        _retrying ||
        provider.isRestoringAppBackup ||
        provider.isDataClearActive) {
      return;
    }
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    widget.onRecoveryBusyChanged?.call(true);
    try {
      await provider.retryStorageLoad();
    } catch (error) {
      if (mounted) setState(() => _retryError = error);
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
        widget.onRecoveryBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = widget.provider;
    final error = _retryError ?? widget.error;
    final message = _retrying
        ? l10n.dataRecoveryRetryAction
        : widget.isSaving
        ? l10n.savingChanges
        : schoolImportSaveBlockedMessage(provider, l10n) ??
              (error == null ? null : mapSchoolImportApplyError(error, l10n));
    if (message == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final busy =
        _retrying || widget.isSaving || provider?.isRestoringAppBackup == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        liveRegion: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 96),
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.error_outline, color: colors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: busy ? colors.onSurface : colors.error,
                    ),
                  ),
                ),
                if (provider?.canWrite == false &&
                    provider?.isRestoringAppBackup != true)
                  TextButton(
                    onPressed: busy ? null : _retryStorageLoad,
                    child: Text(l10n.dataRecoveryRetryAction),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
