import 'package:material_ui/material_ui.dart';

import '../data/timetable_storage.dart';
import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/workspace_view_state.dart';

bool canSaveSchoolImport({
  AppLifecycle? lifecycle,
  AppDataMaintenance? maintenance,
  AppDataClearController? dataClear,
  WorkspaceViewState? workspaceView,
}) =>
    lifecycle?.canWrite != false &&
    maintenance?.isReserved != true &&
    dataClear?.isActive != true &&
    workspaceView?.isEnabled(AppMode.student) != false;

String? schoolImportSaveBlockedMessage(
  AppLocalizations l10n, {
  AppLifecycle? lifecycle,
  AppDataMaintenance? maintenance,
  AppDataClearController? dataClear,
}) {
  if (maintenance?.isReserved == true) {
    return l10n.backupRestoreInProgressMessage;
  }
  if (lifecycle?.isStorageWriteStateUnknown == true) {
    return l10n.dataRecoveryWriteStateUnknownMessage;
  }
  if (lifecycle != null && !lifecycle.canWrite) {
    return switch (lifecycle.storageLoadStatus) {
      StorageLoadStatus.corrupt => l10n.dataRecoveryCorruptMessage,
      StorageLoadStatus.unsupportedVersion =>
        l10n.dataRecoveryUnsupportedVersionMessage,
      _ => l10n.dataRecoveryIoFailureMessage,
    };
  }
  return dataClear?.isActive == true ? l10n.saveFailedRetry : null;
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
    this.lifecycle,
    this.maintenance,
    this.dataClear,
    this.isSaving = false,
    this.error,
    this.onRecoveryBusyChanged,
  });

  final AppLifecycle? lifecycle;
  final AppDataMaintenance? maintenance;
  final AppDataClearController? dataClear;
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
    final lifecycle = widget.lifecycle;
    if (lifecycle == null ||
        widget.isSaving ||
        _retrying ||
        widget.maintenance?.isReserved == true ||
        widget.dataClear?.isActive == true) {
      return;
    }
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    widget.onRecoveryBusyChanged?.call(true);
    try {
      await lifecycle.retryStorageLoad();
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.lifecycle,
      widget.maintenance,
      widget.dataClear,
    ]),
    builder: (context, _) => _buildFeedback(context),
  );

  Widget _buildFeedback(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lifecycle = widget.lifecycle;
    final error = _retryError ?? widget.error;
    final message = _retrying
        ? l10n.dataRecoveryRetryAction
        : widget.isSaving
        ? l10n.savingChanges
        : schoolImportSaveBlockedMessage(
                l10n,
                lifecycle: lifecycle,
                maintenance: widget.maintenance,
                dataClear: widget.dataClear,
              ) ??
              (error == null ? null : mapSchoolImportApplyError(error, l10n));
    if (message == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final busy =
        _retrying || widget.isSaving || widget.maintenance?.isReserved == true;
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
                if (lifecycle?.canWrite == false &&
                    widget.maintenance?.isReserved != true)
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
