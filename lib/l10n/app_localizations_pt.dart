// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Semana $week';
  }

  @override
  String get addCourse => 'Adicionar disciplina';

  @override
  String get settings => 'Configurações';

  @override
  String get multiTimetableSwitch => 'Alternar horários';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Horário atual · $weeks semanas';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Toque para alternar · $weeks semanas';
  }

  @override
  String get editTimetable => 'Editar horário';

  @override
  String get schoolImportResultEditorTitle => 'Editar JSON';

  @override
  String get schoolImportParsePageTitle => 'Analisar horário';

  @override
  String get schoolImportParsePageParsing => 'Analisando…';

  @override
  String get schoolImportParsePageFailed => 'Falha na análise';

  @override
  String get schoolImportParseErrorMessage =>
      'Não foi possível analisar o horário. Verifique o conteúdo, as definições do analisador e a ligação de rede e tente novamente.';

  @override
  String get schoolImportParsePageContinue => 'Continuar';

  @override
  String get schoolImportExpandWarnings => 'Mostrar avisos da importação';

  @override
  String get schoolImportCollapseWarnings => 'Ocultar avisos da importação';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Algumas disciplinas continuam até a semana $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Substituir o horário atual?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'O horário importado substituirá o horário atual.';

  @override
  String get createTimetable => 'Novo horário';

  @override
  String get jumpToWeek => 'Ir para a semana';

  @override
  String get timetable => 'Horário';

  @override
  String get themeWorkspaceSchedule => 'Agenda';

  @override
  String get timetableName => 'Nome do horário';

  @override
  String get timetableNameRequired => 'Digite o nome do horário';

  @override
  String get totalWeeks => 'Total de semanas';

  @override
  String get delete => 'Excluir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Salvar';

  @override
  String get deleteTimetableTitle => 'Excluir horário';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Excluir \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Ainda não há horário';

  @override
  String get noTimetableMessage =>
      'Crie um horário ou escolha uma forma de importação.';

  @override
  String get importTimetable => 'Importar horário';

  @override
  String get courseName => 'Nome da disciplina';

  @override
  String get location => 'Local';

  @override
  String get dayOfWeek => 'Dia';

  @override
  String get semesterWeeks => 'Semanas';

  @override
  String get startTime => 'Horário de início';

  @override
  String get endTime => 'Horário de término';

  @override
  String get linkedPeriods => 'Períodos vinculados';

  @override
  String get linkedPeriodsUnmatched =>
      'Nenhum período corresponde ao horário atual. Toque para escolher manualmente.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Período $start-$end';
  }

  @override
  String get teacherName => 'Professor';

  @override
  String get credits => 'Créditos';

  @override
  String get remarks => 'Observações';

  @override
  String get customFields => 'Campos personalizados';

  @override
  String get customFieldsHint => 'Um por linha, formato: chave:valor';

  @override
  String get customFieldsInvalidJson =>
      'Digite um objeto JSON válido ou limpe o campo.';

  @override
  String get more => 'Mais';

  @override
  String get selectDayOfWeek => 'Escolher dia';

  @override
  String get selectSemesterWeeks => 'Escolher semanas';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get clear => 'Limpar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get selectLinkedPeriods => 'Escolher períodos vinculados';

  @override
  String get addCourseTitle => 'Adicionar disciplina';

  @override
  String get editCourseTitle => 'Editar disciplina';

  @override
  String get editCourseTooltip => 'Editar disciplina';

  @override
  String get place => 'Local';

  @override
  String get time => 'Horário';

  @override
  String get notFilled => 'Não preenchido';

  @override
  String get none => 'Nenhum';

  @override
  String get conflictCourses => 'Disciplinas em conflito';

  @override
  String get locationNotFilled => 'Local não preenchido';

  @override
  String get setAsDisplayed => 'Definir como exibido';

  @override
  String get editThisCourse => 'Editar esta disciplina';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionAppearance => 'Aparência';

  @override
  String get settingsSectionWorkspace => 'Espaço de trabalho';

  @override
  String get settingsSectionAbout => 'Sobre o Sked';

  @override
  String get semesterStartDate => 'Data de início do semestre';

  @override
  String get periodTimeSets => 'Conjunto de horários dos períodos';

  @override
  String get noPeriodTimeAvailable =>
      'Nenhum conjunto de horários dos períodos disponível';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count períodos';
  }

  @override
  String get coursePopupDismissSetting =>
      'Permitir toque fora para fechar o pop-up da disciplina';

  @override
  String get coursePopupDismissSettingHint =>
      'Desativar isso também desativa o fechamento ao deslizar para baixo.';

  @override
  String get preserveTimetableGaps => 'Preservar intervalos no horário';

  @override
  String get preserveTimetableGapsHint =>
      'Quando desativado, os intervalos de almoço e descanso são recolhidos para que as aulas seguintes subam.';

  @override
  String get showPastEndedCourses => 'Mostrar disciplinas já encerradas';

  @override
  String get showPastEndedCoursesHint =>
      'Mostra disciplinas que já terminaram na semana atual real com um estilo cinza mais claro.';

  @override
  String get showFutureCourses => 'Mostrar disciplinas futuras';

  @override
  String get showFutureCoursesHint =>
      'Mostra disciplinas que não estão ativas nesta semana, mas aparecerão nas semanas seguintes, com um estilo cinza.';

  @override
  String get timetableDisplaySettings => 'Exibição e interação do horário';

  @override
  String get timetableDisplaySettingsDesc =>
      'Exibição de aulas, layout, gestos semanais e adição rápida';

  @override
  String get showTimetableGridLines => 'Mostrar linhas da grade do horário';

  @override
  String get timetableHorizontalLayoutSection => 'Layout horizontal e gestos';

  @override
  String get fitDaySelectorToWidth => 'Ajustar o seletor de dias à tela';

  @override
  String get fitDaySelectorToWidthHint =>
      'Mostra os sete dias na tela quando possível. Desative para usar uma largura fixa e rolar.';

  @override
  String get fitWeekColumnsToWidth => 'Ajustar as colunas da semana à tela';

  @override
  String get enableWeekSwipeNavigation => 'Deslizar para mudar de semana';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Deslize para a esquerda ou direita para mudar de semana. Com larguras fixas, arraste primeiro além da borda.';

  @override
  String get liveCourseOutlineSettings => 'Contorno da disciplina';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Configure se o contorno está ativado, o que ele destaca, se segue a cor do tema e qual é a cor efetiva do contorno.';

  @override
  String get liveCourseOutlineEnabled => 'Ativar contorno';

  @override
  String get liveCourseOutlineFollowTheme => 'Seguir a cor do tema';

  @override
  String get liveCourseOutlineTarget => 'Alvo do contorno';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Disciplina atual/próxima';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Todas as disciplinas exibidas';

  @override
  String get liveCourseOutlineEffectiveColor => 'Cor efetiva';

  @override
  String get liveCourseOutlineCustomColor => 'Cor personalizada do contorno';

  @override
  String get liveCourseOutlineWidth => 'Largura do contorno';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Seguir o sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeColor => 'Cor do tema';

  @override
  String get themeColorModeSingle => 'Uma única cor de tema';

  @override
  String get themeColorModeColorful => 'Colorido';

  @override
  String get themeColorUiColors => 'Cores da interface';

  @override
  String get themeColorCourseColors => 'Cores das disciplinas';

  @override
  String get themeColorPrimary => 'Primária';

  @override
  String get themeColorSecondary => 'Secundária';

  @override
  String get themeColorTertiary => 'Terciária';

  @override
  String get themeColorCourseText => 'Texto da disciplina';

  @override
  String get themeColorCourseTextAuto => 'Automático';

  @override
  String get themeColorCourseTextCustom => 'Cor personalizada';

  @override
  String get themeColorCourseColorsEmpty =>
      'As cores das disciplinas serão geradas após importar um horário.';

  @override
  String get themeCustomColor => 'Cor personalizada';

  @override
  String get themeApplyCustomColor => 'Aplicar cor';

  @override
  String get themeApplySettings => 'Aplicar configurações';

  @override
  String get dataImportExport => 'Importar e exportar dados';

  @override
  String get dataImportExportDesc =>
      'Importe todos os dados ou horários individuais, ou exporte o horário atual/todos os horários.';

  @override
  String get appBackupTitle => 'Backup e restauração do app';

  @override
  String get appBackupSheetSubtitle =>
      'Uma restauração completa substitui os dados atuais do app. As chaves da API de IA ficam no armazenamento seguro e não são gravadas nos arquivos de backup.';

  @override
  String get restoreBackupFileTitle => 'Restaurar de arquivo JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Escolha um arquivo de backup completo do Sked. Você confirmará antes de restaurar.';

  @override
  String get restoreBackupTextTitle => 'Colar JSON de backup';

  @override
  String get restoreBackupTextSubtitle =>
      'Cole um backup completo e restaure os dados atuais do app.';

  @override
  String get shareBackupTitle => 'Compartilhar arquivo de backup';

  @override
  String get shareBackupSubtitle =>
      'Exporte todos os dados do app como JSON. As chaves de API são excluídas.';

  @override
  String get saveBackupTitle => 'Salvar arquivo de backup';

  @override
  String get saveBackupSubtitle =>
      'Salve um backup completo do app em um arquivo local.';

  @override
  String get copyBackupTitle => 'Copiar texto de backup';

  @override
  String get copyBackupSubtitle =>
      'Mostra o JSON completo do backup para que você possa copiá-lo ou armazená-lo temporariamente.';

  @override
  String get restoreBackupConfirmTitle => 'Restaurar backup completo?';

  @override
  String get restoreBackupConfirmMessage =>
      'Isto substituirá todos os horários, agendas gerais, configurações e sites escolares atuais. As chaves de API não são importadas dos backups; insira a chave novamente antes de analisar horários outra vez.';

  @override
  String get restoreBackupConfirmAction => 'Restaurar backup';

  @override
  String get restoreBackupSuccessMessage =>
      'Backup completo do app restaurado. As chaves da API de IA precisam ser inseridas novamente.';

  @override
  String get restoreBackupFailureMessage =>
      'Falha ao restaurar. Verifique o conteúdo do backup e tente novamente.';

  @override
  String get openSourceLicenses => 'Licenças de código aberto';

  @override
  String get openSourceLicensesDesc =>
      'Veja as licenças das dependências do Flutter e dos recursos do ícone do app incluídos.';

  @override
  String get checkForUpdates => 'Verificar atualizações';

  @override
  String get includePrereleaseUpdates => 'Receber versões de pré-lançamento';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Incluir versões Alpha, Beta e RC, que podem ser instáveis. Quando desativado, apenas versões estáveis são oferecidas.';

  @override
  String get currentVersionLabel => 'Versão atual';

  @override
  String get newVersionAvailable => 'Atualização disponível';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'Ignorar esta versão';

  @override
  String get openUpdatesFailed =>
      'Não foi possível abrir o link de atualização';

  @override
  String get updateCheckFailedTitle => 'Falha ao verificar atualizações';

  @override
  String get githubRepository => 'Repositório no GitHub';

  @override
  String get googlePlayStoreDesc => 'Ver o Sked no Google Play';

  @override
  String get openGooglePlayFailed => 'Não foi possível abrir o Google Play';

  @override
  String get microsoftStoreDesc => 'Ver o Sked na Microsoft Store';

  @override
  String get openMicrosoftStoreFailed =>
      'Não foi possível abrir a Microsoft Store';

  @override
  String get starSkedOnGithub => 'Dê uma estrela ao Sked no GitHub!';

  @override
  String get openGithubFailed =>
      'Não foi possível abrir o link do repositório no GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Não foi possível abrir o link da política de privacidade';

  @override
  String get selectPeriodTimeSet =>
      'Escolher conjunto de horários dos períodos';

  @override
  String get newItem => 'Novo';

  @override
  String get editPeriodTimeSet => 'Editar conjunto de horários dos períodos';

  @override
  String get importTimetableFiles => 'Importar horário';

  @override
  String get importTimetableFilesDesc =>
      'Suporta um ou vários arquivos de horário.';

  @override
  String get importTimetableText => 'Importar horário a partir de texto';

  @override
  String get importTimetableTextDesc =>
      'Cole o conteúdo JSON do horário e importe.';

  @override
  String get shareTimetableFiles => 'Compartilhar arquivos de horário';

  @override
  String get shareTimetableFilesDesc => 'Escolha um ou mais horários primeiro.';

  @override
  String get saveTimetableFiles => 'Salvar arquivos de horário';

  @override
  String get saveTimetableFilesDesc => 'Escolha um ou mais horários primeiro.';

  @override
  String get exportTimetableText => 'Exportar horário como texto';

  @override
  String get exportTimetableTextDesc =>
      'Escolha um ou mais horários e depois copie o conteúdo JSON.';

  @override
  String get jsonContent => 'Conteúdo JSON';

  @override
  String get pasteJsonContentHint => 'Cole o conteúdo JSON para importar.';

  @override
  String get jsonContentEmpty => 'Cole primeiro o conteúdo JSON.';

  @override
  String get copyText => 'Copiar';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get copyFailed => 'Could not copy. Please try again.';

  @override
  String get share => 'Compartilhar';

  @override
  String get selectTimetablesToExport => 'Escolher horários para exportar';

  @override
  String get selectTimetablesToImport => 'Escolher horários para importar';

  @override
  String get studentDayNextCourse => 'Next course';

  @override
  String get studentDayNoMoreCourses =>
      'No later courses in this timetable\'s semester.';

  @override
  String get studentDayEmpty => 'Não há aulas neste dia';

  @override
  String timetableCourseCount(int count) {
    return '$count disciplinas';
  }

  @override
  String get importAction => 'Importar';

  @override
  String get importTimetableDialogTitle => 'Importar horário';

  @override
  String get chooseImportMethod => 'Escolha como importar.';

  @override
  String get importAsNewTimetable => 'Importar como novo horário';

  @override
  String get replaceCurrentTimetable => 'Substituir o horário atual';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Importar conjuntos de horários dos períodos';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Este arquivo contém conjuntos de horários dos períodos incluídos. Deseja importá-los e associá-los?';

  @override
  String get importBundledPeriodTimeSets => 'Importar e associar';

  @override
  String get discardBundledPeriodTimeSets => 'Descartar conjuntos incluídos';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Nenhum conjunto de horários dos períodos existente está disponível, portanto os conjuntos incluídos não podem ser descartados.';

  @override
  String savedToPath(Object path) {
    return 'Salvo em $path';
  }

  @override
  String get saveCancelled => 'Salvamento cancelado';

  @override
  String get fileSaveRestrictedTitle => 'Salvamento de arquivo restrito';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'O sistema não pôde salvar o arquivo. Você pode tentar novamente ou usar o compartilhamento.';

  @override
  String get retrySave => 'Tentar salvar novamente';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Ative o acesso a arquivos nas configurações do sistema e depois volte para tentar exportar novamente.';

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String get browserDownloadRestrictedTitle => 'Download no navegador restrito';

  @override
  String get browserDownloadRestrictedMessage =>
      'Este navegador não oferece suporte para salvar diretamente em um arquivo local. Verifique as permissões de download do navegador ou use o compartilhamento de arquivos.';

  @override
  String get switchToShare => 'Usar compartilhamento em vez disso';

  @override
  String get fileSaveFailedTitle => 'Falha ao salvar arquivo';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Não foi possível gravar no caminho atual. A pasta de destino pode estar protegida, o arquivo pode estar em uso ou o caminho pode não permitir gravação.';

  @override
  String get fileSaveFailedGenericMessage =>
      'O sistema não pôde salvar o arquivo. Você pode tentar novamente, verificar as configurações do sistema ou usar o compartilhamento de arquivos.';

  @override
  String get retryLater => 'Tente novamente mais tarde';

  @override
  String get exportSwitchedToShare =>
      'Exportação alterada para compartilhamento de arquivos';

  @override
  String get saveFailedRetry => 'Falha ao salvar. Tente novamente mais tarde.';

  @override
  String get periodTimesUnsavedExitTitle => 'Alterações não salvas';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Não foi possível salvar as últimas alterações nos horários dos períodos. Você pode tentar novamente, continuar editando ou descartá-las.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Alguns horários de períodos são inválidos. Corrija-os antes de salvar ou descarte as alterações e saia.';

  @override
  String get discardChangesAndExit => 'Descartar e sair';

  @override
  String get appInstanceBlockedTitle => 'O Sked já está aberto';

  @override
  String get appInstanceBlockedMessage =>
      'Outra janela do Sked ou guia do navegador está usando seus dados locais. Feche-a e tente novamente.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Os dados locais estão indisponíveis';

  @override
  String get appInstanceLeaseFailedMessage =>
      'O Sked não conseguiu confirmar o acesso exclusivo aos dados locais. Seus dados não foram abertos nem alterados. Verifique o acesso ao armazenamento e tente novamente.';

  @override
  String get savingChanges => 'Salvando alterações...';

  @override
  String get showApiKey => 'Mostrar chave de API';

  @override
  String get hideApiKey => 'Ocultar chave de API';

  @override
  String get importFailedCheckContent =>
      'Falha na importação. Verifique o conteúdo do arquivo.';

  @override
  String get noImportableTimetables =>
      'Nenhum horário utilizável foi encontrado no arquivo importado.';

  @override
  String importedTimetablesCount(int count) {
    return '$count horários importados';
  }

  @override
  String get periodTimesTitle => 'Horários dos períodos';

  @override
  String get importExport => 'Importar e exportar';

  @override
  String get importPeriodTemplate => 'Importar modelo de períodos';

  @override
  String get importPeriodTemplateText =>
      'Importar modelo de períodos a partir de texto';

  @override
  String get sharePeriodTemplate => 'Compartilhar modelo de períodos';

  @override
  String get saveTemplateToFile => 'Salvar modelo em arquivo';

  @override
  String get exportPeriodTemplateText =>
      'Exportar modelo de períodos como texto';

  @override
  String get deletePeriodTimeSet => 'Excluir conjunto de horários dos períodos';

  @override
  String get periodTimeSetName => 'Nome do conjunto de horários dos períodos';

  @override
  String get addOnePeriod => 'Adicionar período';

  @override
  String periodNumberLabel(int index) {
    return 'Período $index';
  }

  @override
  String get deleteThisPeriod => 'Excluir este período';

  @override
  String durationMinutes(int minutes) {
    return 'Duração $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Intervalo desde o anterior $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'O horário de término deve ser posterior ao de início';

  @override
  String get periodOverlapPrevious => 'Este período se sobrepõe ao anterior';

  @override
  String get periodTimesSaved => 'Horários dos períodos salvos';

  @override
  String get deletePeriodTimeSetTitle =>
      'Excluir conjunto de horários dos períodos';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Excluir \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'conjunto atual de horários dos períodos';

  @override
  String importedPeriodTimesCount(int count) {
    return '$count horários de períodos importados';
  }

  @override
  String get periodFilePermissionTitle => 'Permissão de arquivo necessária';

  @override
  String get androidFilePermissionMessage =>
      'A exportação no Android exige permissão de acesso a arquivos. Conceda a permissão para continuar salvando.';

  @override
  String get reauthorize => 'Autorizar novamente';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Permissão negada permanentemente';

  @override
  String get permissionSettingsExportMessage =>
      'Ative o acesso a arquivos nas configurações do sistema e depois volte para tentar exportar novamente.';

  @override
  String get privacyPolicyTitle => 'Política de Privacidade';

  @override
  String get privacyPolicyEntryDesc =>
      'Saiba como o app lida com armazenamento local, configuração de sites escolares, importação/exportação de arquivos, análise de páginas web e links externos.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Versão aceita: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'O Sked é uma ferramenta de horários que dá prioridade ao armazenamento local. Os horários de aulas, as agendas gerais, os conjuntos de horas das aulas e a configuração dos sites das escolas são guardados apenas no seu dispositivo ou navegador e nunca são enviados automaticamente. A aplicação só processa dados quando inicia explicitamente ações como importar, analisar texto / HTML de horários, importar páginas web de escolas, partilhar ou abrir ligações externas. A política de privacidade completa está disponível online.';

  @override
  String get privacyGateTitle =>
      'Concorde com a política de privacidade antes de usar o app';

  @override
  String get privacyGateSummaryStorage =>
      'Os horários de aulas, as agendas gerais, os conjuntos de horas das aulas e a configuração dos sites das escolas são guardados apenas localmente e não são enviados automaticamente para um servidor do programador.';

  @override
  String get privacyGateSummaryImportExport =>
      'A importação, a exportação, as cópias de segurança completas e a partilha só acontecem quando as inicia explicitamente. As cópias de segurança completas da aplicação não incluem chaves API personalizadas, e a análise de texto / HTML de horários envia apenas o conteúdo submetido para o ponto de acesso de análise configurado.';

  @override
  String get privacyGateSummaryUpdates =>
      'Se uma versão posterior alterar como os dados são tratados, o app poderá pedir que você revise novamente a política de privacidade atualizada.';

  @override
  String get schoolWebImportEntry => 'Importar da página web da escola';

  @override
  String get schoolWebImportEntryDesc =>
      'Importe a página atual do horário a partir do site da escola.';

  @override
  String get schoolSitesPageTitle => 'Gerenciamento de sites escolares';

  @override
  String get schoolSitesImportJson => 'Importar JSON de escolas';

  @override
  String get schoolSitesShareJson => 'Compartilhar JSON de escolas';

  @override
  String get schoolSitesSaveJson => 'Salvar JSON de escolas';

  @override
  String get schoolSitesSaved => 'Sites escolares salvos';

  @override
  String get schoolSitesImported => 'Sites escolares importados';

  @override
  String get schoolSitesImportPreviewTitle =>
      'Revisar a importação de sites escolares';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount sites válidos, $invalidCount entradas inválidas.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'O arquivo contém uma lista vazia de sites escolares.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'A entrada $position é inválida e será ignorada.';
  }

  @override
  String get schoolSitesImportMerge => 'Mesclar';

  @override
  String get schoolSitesImportReplace => 'Substituir';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Substituir os sites escolares atuais?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Isso remove $currentCount sites atuais e salva $importedCount sites importados. Esta ação não pode ser desfeita.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Os dados dos sites escolares precisam de recuperação';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'O Sked não conseguiu ler o arquivo de sites escolares nem seu backup. Cópias protegidas foram criadas antes de bloquear a gravação.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'O armazenamento dos sites escolares está indisponível';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'O Sked não consegue acessar o armazenamento de sites escolares no momento. Verifique o acesso ao armazenamento e a disponibilidade do dispositivo e tente novamente. Os dados atuais dos sites não serão sobrescritos.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Os arquivos de recuperação e os locais de armazenamento afetados estão listados abaixo. Não altere os arquivos até que a lista de sites seja recuperada.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Recomeçar sem sites escolares';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Recomeçar com uma lista vazia de sites escolares?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'As cópias protegidas serão mantidas, mas o Sked criará um novo arquivo vazio de sites escolares. Continue apenas se não quiser tentar a recuperação novamente primeiro.';

  @override
  String get schoolSitesEmpty => 'Ainda não há configuração de site escolar.';

  @override
  String get schoolSitesNameLabel => 'Nome da escola';

  @override
  String get schoolSitesLoginUrlLabel => 'URL de login';

  @override
  String get schoolSitesAdd => 'Adicionar escola';

  @override
  String get schoolSitesEdit => 'Editar escola';

  @override
  String get schoolSitesDeleteTitle => 'Excluir escola';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Excluir \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Preencha primeiro o nome da escola e a URL de login.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importar colando o conteúdo da página do horário';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Cole manualmente o código-fonte ou o conteúdo bruto da página que contém as informações do horário.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analisar horário a partir do conteúdo da página';

  @override
  String get schoolHtmlImportHtmlLabel => 'Conteúdo da página';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Cole aqui o código-fonte ou o conteúdo bruto da página que contém as informações do horário.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Qualquer conteúdo que contenha informações do horário pode ser analisado e importado, não apenas HTML.';

  @override
  String get schoolHtmlImportCompress => 'Preparar conteúdo';

  @override
  String get schoolHtmlImportCompressed => 'Conteúdo preparado';

  @override
  String get schoolHtmlImportSubmit => 'Analisar e importar';

  @override
  String get schoolImportContentTruncated =>
      'Esta página atingiu o limite de importação segura. Apenas a parte capturada será enviada para análise.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'A análise pode demorar um pouco. Aguarde.';

  @override
  String get schoolHtmlImportEmpty => 'Cole primeiro o HTML da página.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Voltar para a página web';

  @override
  String get schoolWebImportPreview => 'Pré-visualização da importação';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count disciplinas';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count períodos';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Título da página';

  @override
  String get schoolWebImportWarnings => 'Observações da importação';

  @override
  String get schoolWebImportParserDetails => 'Detalhes da análise';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Expandir detalhes da análise';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Recolher detalhes da análise';

  @override
  String get schoolWebImportOpenPageHint =>
      'Entre no site da escola dentro do app e depois navegue manualmente até a página do horário.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Esta plataforma ainda não oferece suporte para login web incorporado. Use uma plataforma com suporte a WebView.';

  @override
  String get schoolWebImportNoSchools =>
      'Nenhuma configuração de escola está disponível. Verifique primeiro o school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Não foi possível carregar a configuração da escola. Tente novamente.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importar página atual';

  @override
  String get schoolWebImportLoadFailed =>
      'Falha ao carregar a página. Atualize ou tente novamente mais tarde.';

  @override
  String get schoolWebImportUnknownOrigin => 'Site desconhecido';

  @override
  String get schoolWebImportExitTitle => 'Sair do navegador?';

  @override
  String get schoolWebImportExitMessage =>
      'A página será fechada. Tudo o que ainda não importou será perdido.';

  @override
  String get schoolWebImportExitConfirm => 'Sair';

  @override
  String get schoolWebImportEmptyPage =>
      'O conteúdo da página atual está vazio e ainda não pode ser importado.';

  @override
  String get schoolWebImportSuccess => 'Horário web importado';

  @override
  String get schoolImportWithoutApiTitle => 'Add a timetable without an API';

  @override
  String get schoolImportManualHint =>
      'To add courses manually, return to the timetable workspace, create or select a timetable, then choose Add course.';

  @override
  String get schoolImportFileAction => 'Import timetable JSON';

  @override
  String get schoolImportAiHint =>
      'To parse pasted content or a school webpage, connect an OpenAI-compatible API. The content you submit will be sent to that endpoint.';

  @override
  String get schoolImportConfigureAction => 'Configure parsing API';

  @override
  String get schoolImportParserSettingsTitle => 'API de importação de horários';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure a API compatível com OpenAI para importar horários, não para um assistente de conversa.';

  @override
  String get schoolImportParserSourceTitle => 'Origem do analisador';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Compatível com OpenAI personalizado';

  @override
  String get schoolImportParserCustomPromptTitle => 'Prompt personalizado';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Edite aqui o prompt integrado do analisador. As alterações afetam apenas o analisador personalizado compatível com OpenAI.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'O prompt integrado é carregado aqui por padrão. Limpe-o para voltar à versão integrada.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Restaurar prompt padrão';

  @override
  String get schoolImportParserBaseUrl => 'URL base';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'A Base URL deve ser uma URL HTTP ou HTTPS com host.';

  @override
  String get schoolImportParserApiKey => 'Chave de API';

  @override
  String get schoolImportParserModel => 'Modelo';

  @override
  String get schoolImportParserFetchModels => 'Buscar lista de modelos';

  @override
  String get schoolImportParserFetchingModels => 'Buscando modelos...';

  @override
  String get schoolImportParserNoModelsFound =>
      'Nenhum modelo foi retornado pelo endpoint.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Não foi possível obter os modelos. Verifique o endpoint e tente novamente.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return '$count modelos obtidos';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'A chave de API personalizada é guardada no armazenamento seguro da plataforma quando disponível. Use credenciais do analisador personalizado e endpoints HTTP apenas em dispositivos, navegadores e redes confiáveis.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Usar um endpoint HTTP não encriptado?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'A chave da API e o conteúdo do horário podem ser lidos ou alterados durante a transmissão. Continue apenas se confiar neste dispositivo, na rede e no endpoint. Esta autorização é válida até fechar o Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'A configuração do analisador personalizado está incompleta. Preencha primeiro a URL base, a chave de API e o modelo.';

  @override
  String get clearAppData => 'Apagar dados';

  @override
  String get clearAppDataDesc =>
      'Excluir permanentemente todos os dados locais do Sked e sair do aplicativo';

  @override
  String get clearAppDataConfirmTitle => 'Apagar todos os dados do Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Isso exclui permanentemente horários, agendas, configurações, sites escolares, backups locais, cópias de recuperação e a chave da API de IA e, em seguida, fecha o Sked. Os arquivos exportados para outros locais não são excluídos. Esta ação não pode ser desfeita.';

  @override
  String get clearAppDataAction => 'Apagar dados e sair';

  @override
  String get clearAppDataFailed =>
      'Não foi possível apagar todos os dados locais. O Sked permanecerá aberto para você tentar novamente.';

  @override
  String get clearAppDataExitFailed =>
      'Seus dados locais foram apagados, mas o Sked não conseguiu fechar. Feche o aplicativo manualmente antes de usá-lo novamente.';

  @override
  String get privacyViewFullPolicy => 'Ver política de privacidade completa';

  @override
  String get privacyAgreeAndContinue => 'Concordar e continuar';

  @override
  String get privacyDecline => 'Recusar';

  @override
  String get privacyDeclineWebHint =>
      'Este ambiente de navegador não permite que o app feche a página por você. Se não concordar, feche esta aba ou janela manualmente.';

  @override
  String get defaultPeriodTimeSetName => 'Períodos padrão';

  @override
  String get periodTimeSetFallbackName => 'Horários dos períodos';

  @override
  String get untitledTimetableName => 'Horário sem título';

  @override
  String get newTimetableName => 'Novo horário';

  @override
  String get newPeriodTimeSetName => 'Novo conjunto de horários dos períodos';

  @override
  String get emptyTimetableName => 'Horário vazio';

  @override
  String importedPeriodTimeSetName(Object name) {
    return 'Períodos de $name';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'O tipo de arquivo importado não corresponde.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Esta versão do arquivo de importação ainda não é compatível.';

  @override
  String get importEntryLimitExceededMessage =>
      'This import contains too many entries or overly nested data. Reduce the exported content and try again.';

  @override
  String get confirmImportedStartDatesTitle => 'Confirm semester start dates';

  @override
  String get confirmImportedStartDatesMessage =>
      'These timetables have no valid semester start date in the import. The dates below initially use today. Review them before importing.';

  @override
  String get importStartDateConfirmationRequiredMessage =>
      'Confirm the missing semester start dates before importing.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Nenhum horário de período foi encontrado no arquivo importado.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Selecione pelo menos um horário.';

  @override
  String get noExportableTimetableMessage =>
      'Não há horário disponível para exportar.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Substituir o horário atual permite selecionar apenas um horário.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'O horário selecionado para substituição não está disponível. Selecione novamente.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Este conjunto de horários dos períodos ainda é usado por $count horário(s). Reatribua-os antes de excluir.';
  }

  @override
  String get weekdayMonday => 'Segunda-feira';

  @override
  String get weekdayTuesday => 'Terça-feira';

  @override
  String get weekdayWednesday => 'Quarta-feira';

  @override
  String get weekdayThursday => 'Quinta-feira';

  @override
  String get weekdayFriday => 'Sexta-feira';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get weekdayShortMonday => 'Seg';

  @override
  String get weekdayShortTuesday => 'Ter';

  @override
  String get weekdayShortWednesday => 'Qua';

  @override
  String get weekdayShortThursday => 'Qui';

  @override
  String get weekdayShortFriday => 'Sex';

  @override
  String get weekdayShortSaturday => 'Sáb';

  @override
  String get weekdayShortSunday => 'Dom';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'Fev';

  @override
  String get monthMarch => 'Mar';

  @override
  String get monthApril => 'Abr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJune => 'Jun';

  @override
  String get monthJuly => 'Jul';

  @override
  String get monthAugust => 'Ago';

  @override
  String get monthSeptember => 'Set';

  @override
  String get monthOctober => 'Out';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Dez';

  @override
  String get semesterWeeksWholeTerm => 'Todo o semestre';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Semanas $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Semanas $value';
  }

  @override
  String get generalSchedule => 'Agenda';

  @override
  String get studentTimetable => 'Horário';

  @override
  String get firstLaunchTitle => 'Escolha os espaços de trabalho a ativar';

  @override
  String get firstLaunchSubtitle =>
      'Use o horário, a agenda ou ambos. Você pode mudar essa escolha depois nas configurações.';

  @override
  String get firstLaunchStudentDesc =>
      'Gerencie horários, cursos, semanas, períodos e importações.';

  @override
  String get firstLaunchGeneralDesc =>
      'Gerencie categorias, eventos, lembretes e dados JSON / ICS.';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Ao escolher um espaço de trabalho, você confirma que leu e aceita a ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Política de privacidade';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Alternar modo';

  @override
  String get switchToStudentTimetable => 'Mudar para o horário';

  @override
  String get today => 'Hoje';

  @override
  String get addEvent => 'Adicionar evento';

  @override
  String get editEvent => 'Editar evento';

  @override
  String get eventTitle => 'Título';

  @override
  String get eventTitleRequired => 'Digite um título';

  @override
  String get eventStartTime => 'Hora de início';

  @override
  String get eventEndTime => 'Hora de término';

  @override
  String get eventDate => 'Data';

  @override
  String get eventTime => 'Hora';

  @override
  String get eventNotes => 'Notas';

  @override
  String get eventColor => 'Cor';

  @override
  String get eventRecurrence => 'Repetir';

  @override
  String get recurrenceNone => 'Não se repete';

  @override
  String get recurrenceWeekly => 'Semanal';

  @override
  String get recurrenceEndDate => 'Data de término';

  @override
  String get repeatsWeekly => 'Repete semanalmente';

  @override
  String recurrenceUntil(Object date) {
    return 'Até $date';
  }

  @override
  String get switchToGeneralSchedule => 'Mudar para a agenda';

  @override
  String get generalDisplaySettings => 'Configurações gerais de exibição';

  @override
  String get generalDisplaySettingsDesc =>
      'Visualizações, barra de ferramentas, formato de data e adição rápida';

  @override
  String get closePopupOnOutsideTap => 'Fechar o popup ao tocar fora';

  @override
  String get showGridLines => 'Mostrar linhas da grade';

  @override
  String get generalScheduleImportExport => 'Importar e exportar categorias';

  @override
  String get generalScheduleImportExportDesc =>
      'Importar ou compartilhar categorias da agenda';

  @override
  String get importGeneralSchedules => 'Importar categorias';

  @override
  String get importGeneralSchedulesDesc => 'Ler categorias de um arquivo JSON';

  @override
  String get shareGeneralSchedules => 'Compartilhar categorias';

  @override
  String get shareGeneralSchedulesDesc =>
      'Compartilhar categorias como arquivo JSON';

  @override
  String get saveGeneralSchedules => 'Salvar categorias';

  @override
  String get saveGeneralSchedulesDesc => 'Salvar categorias como arquivo JSON';

  @override
  String get selectSchedulesToExport => 'Selecionar categorias para exportar';

  @override
  String get selectSchedulesToImport => 'Selecionar categorias para importar';

  @override
  String generalScheduleEventCount(int count) {
    return 'Eventos: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return '$count categorias importadas';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Adicionar a importação como nova categoria ou substituir uma existente?';

  @override
  String get addAsNewSchedule => 'Adicionar como nova categoria';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Selecione pelo menos uma categoria.';

  @override
  String get noExportableScheduleMessage =>
      'Nenhuma categoria disponível para exportar.';

  @override
  String get noSchedulesInImportMessage =>
      'O arquivo importado não contém categorias.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Escolha exatamente uma categoria importada para a substituição.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'A categoria selecionada para substituição está indisponível.';

  @override
  String get calendars => 'Categorias';

  @override
  String get calendar => 'Categoria';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewDay => 'Dia';

  @override
  String get viewList => 'Lista';

  @override
  String get viewMonth => 'Mês';

  @override
  String visibleCategoryCount(int count) {
    return '$count categorias';
  }

  @override
  String get noVisibleCategories => 'Nenhuma categoria visível';

  @override
  String get selectCategoryToReplace => 'Escolher categoria para substituir';

  @override
  String get replaceCategory => 'Substituir categoria';

  @override
  String get deleteEventTitle => 'Excluir evento';

  @override
  String get deleteEventConfirmation =>
      'Este evento será excluído permanentemente.';

  @override
  String get deleteRecurringEventTitle => 'Excluir evento recorrente';

  @override
  String get eventDuplicated => 'Evento duplicado';

  @override
  String get allDay => 'Dia inteiro';

  @override
  String get collapseAllDayTimeline => 'Recolher eventos de dia inteiro';

  @override
  String get expandAllDayTimeline => 'Expandir eventos de dia inteiro';

  @override
  String allDayEventsCount(int count) {
    return '$count eventos de dia inteiro';
  }

  @override
  String moreEvents(int count) {
    return '+$count mais';
  }

  @override
  String get noMatchingEvents => 'Nenhum evento correspondente';

  @override
  String get noUpcomingEvents => 'Nenhum evento próximo';

  @override
  String get addCalendar => 'Adicionar categoria';

  @override
  String get newCalendar => 'Nova categoria';

  @override
  String get hideCalendar => 'Ocultar categoria';

  @override
  String get showCalendar => 'Mostrar categoria';

  @override
  String get rename => 'Renomear';

  @override
  String get renameCalendar => 'Renomear categoria';

  @override
  String get name => 'Nome';

  @override
  String get deleteCalendar => 'Excluir categoria';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Excluir “$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Excluir esta ocorrência';

  @override
  String get deleteFutureOccurrences => 'Excluir esta e as seguintes';

  @override
  String get deleteAllOccurrences => 'Excluir toda a série';

  @override
  String get duplicateEvent => 'Duplicar';

  @override
  String get repeatsDaily => 'Repete diariamente';

  @override
  String get repeatsMonthly => 'Repete mensalmente';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Repete a cada $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count vezes';
  }

  @override
  String get recurrenceDaily => 'Diária';

  @override
  String get recurrenceMonthly => 'Mensal';

  @override
  String get recurrenceCustom => 'Personalizada';

  @override
  String get recurrenceEvery => 'A cada';

  @override
  String get recurrenceUnit => 'Unidade';

  @override
  String get recurrenceDays => 'Dias';

  @override
  String get recurrenceWeeks => 'Semanas';

  @override
  String get recurrenceMonths => 'Meses';

  @override
  String get recurrenceRepeatCount => 'Número de repetições';

  @override
  String get recurrenceNoLimit => 'Sem limite';

  @override
  String get recurrencePositiveNumber => 'Digite um número positivo';

  @override
  String get clearEndDate => 'Limpar data de término';

  @override
  String get pickDate => 'Escolher data';

  @override
  String get pickTime => 'Escolher hora';

  @override
  String get reminder => 'Lembrete';

  @override
  String get reminderAtStart => 'No início';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min antes';
  }

  @override
  String get reminderHourBefore => '1 hora antes';

  @override
  String get reminderDayBefore => '1 dia antes';

  @override
  String get markReminderHandled => 'Marcar como tratado';

  @override
  String get restoreReminder => 'Restaurar o lembrete no aplicativo';

  @override
  String get reminderHandled => 'Lembrete no aplicativo marcado como tratado';

  @override
  String get reminderRestored => 'Lembrete no aplicativo restaurado';

  @override
  String get reminderUpcoming => 'Próximos';

  @override
  String get generalFitWeekColumnsToWidth => 'Ajustar a semana ao ecrã';

  @override
  String get showWeekends => 'Mostrar fins de semana';

  @override
  String get startHour => 'Hora inicial';

  @override
  String get endHour => 'Hora final';

  @override
  String get timeGridDensity => 'Densidade da grade de horários';

  @override
  String get timeGridHourHeight => 'Altura das linhas de hora';

  @override
  String get timeGridHourHeightHint =>
      'Ajusta a escala vertical das visualizações diária e semanal sem alterar o intervalo de 15, 30 ou 60 minutos da grade.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importar arquivo JSON';

  @override
  String get pasteJson => 'Colar JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importar categorias do JSON copiado';

  @override
  String get importIcsFile => 'Importar arquivo ICS';

  @override
  String get importIcsFileDesc =>
      'Ler eventos de um arquivo de calendário .ics';

  @override
  String get pasteIcs => 'Colar ICS';

  @override
  String get pasteIcsDesc => 'Importar eventos do texto de calendário copiado';

  @override
  String get copyJson => 'Copiar JSON';

  @override
  String get copyJsonDesc =>
      'Copiar as categorias selecionadas como texto JSON';

  @override
  String get shareIcs => 'Compartilhar ICS';

  @override
  String get shareIcsDesc =>
      'Compartilhar os calendários selecionados como .ics';

  @override
  String get saveIcs => 'Salvar ICS';

  @override
  String get saveIcsDesc => 'Salvar os calendários selecionados como .ics';

  @override
  String get copyIcs => 'Copiar ICS';

  @override
  String get copyIcsDesc => 'Copiar os calendários selecionados como texto ICS';

  @override
  String get importIcs => 'Importar ICS';

  @override
  String get icsContent => 'Conteúdo ICS';

  @override
  String get pasteIcsContentHint =>
      'Cole aqui o conteúdo que começa com BEGIN:VCALENDAR';

  @override
  String get icsReminderExportTitle => 'A exportação ICS não inclui lembretes';

  @override
  String get icsReminderExportMessage =>
      'Os lembretes não são incluídos no ICS exportado. Escolha JSON para manter as configurações dos lembretes.';

  @override
  String get icsReminderExportJsonAction => 'Exportar JSON';

  @override
  String get icsReminderExportContinueAction => 'Continuar com ICS';

  @override
  String get icsReminderImportNotice =>
      'Os eventos importados de ICS terão os lembretes desativados. Use JSON para restaurar as configurações dos lembretes.';

  @override
  String get icsReminderReplaceTitle => 'Substituir eventos e lembretes?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'Substituir “$calendar” por eventos ICS sobrescreverá os eventos da categoria e desativará seus lembretes. Cancele para exportar primeiro um backup JSON ou volte e adicione uma nova categoria.';
  }

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count eventos encontrados. Adicioná-los como nova categoria ou substituir uma existente?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return '$count categorias importadas com $warningCount avisos';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Um evento sem hora de início foi ignorado.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Um evento com hora de início não compatível foi ignorado.';

  @override
  String get importWarningAdjustedEnd =>
      'Foi ajustado um evento cuja hora de término não era posterior à de início.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Os campos ICS não suportados foram ignorados: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Frequência de repetição não compatível ignorada: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Selecionar calendários para copiar como ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Selecionar calendários para exportar como ICS';

  @override
  String get exportIcsText => 'Exportar texto ICS';

  @override
  String get exportJsonText => 'Exportar texto JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Os dados do aplicativo foram restaurados do backup anterior porque o arquivo principal não pôde ser carregado.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'O arquivo principal de dados e seu backup estão danificados. O aplicativo está usando um estado inicial.';

  @override
  String get dataRecoveryCorruptTitle => 'Seus dados precisam de recuperação';

  @override
  String get dataRecoveryCorruptMessage =>
      'O Sked não conseguiu ler o arquivo principal de dados nem seu backup. Cópias protegidas foram criadas antes de bloquear a gravação.';

  @override
  String get dataRecoveryIoFailureTitle => 'O armazenamento está indisponível';

  @override
  String get dataRecoveryIoFailureMessage =>
      'O Sked não consegue acessar o armazenamento local no momento. Verifique o acesso ao armazenamento e a disponibilidade do dispositivo e tente novamente. Os dados existentes não serão sobrescritos.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Atualize o Sked para abrir estes dados';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Estes dados foram criados por uma versão mais recente do Sked. Atualize o aplicativo antes de tentar novamente. A opção de recomeçar com dados vazios está desativada para protegê-los.';

  @override
  String get dataRecoveryRetryAction => 'Tentar novamente';

  @override
  String get dataRecoveryArtifactsHint =>
      'Os arquivos de recuperação e os locais de armazenamento afetados estão listados abaixo. Não altere os arquivos até que seus dados sejam recuperados.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Mostrar arquivos e locais de recuperação';

  @override
  String get dataRecoveryStartFreshAction => 'Começar com novos dados';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Começar com novos dados?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'As cópias protegidas serão mantidas, mas o Sked criará um novo arquivo de dados local. Continue apenas se não quiser tentar a recuperação novamente primeiro.';

  @override
  String get previousMonth => 'Mês anterior';

  @override
  String get nextMonth => 'Próximo mês';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Em andamento';

  @override
  String get deleteCourseTitle => 'Excluir disciplina';

  @override
  String get deleteCourseMessage => 'Excluir esta disciplina?';

  @override
  String get showLunarCalendar => 'Mostrar calendário lunar';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count eventos';
  }

  @override
  String get defaultView => 'Visualização padrão';

  @override
  String get generalDefaultViewSection => 'Ao iniciar';

  @override
  String get generalViewSwitchBehavior => 'Botão de mudança de visualização';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Ocultar navegação entre espaços de trabalho';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Oculte a navegação entre espaços. Pode continuar a mudar de espaço no menu do ecrã principal.';

  @override
  String get generalDateLabelFormat => 'Formato de exibição da data';

  @override
  String get generalDateLabelFormatLocalized => 'Localizado (jul. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Barras (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Layout da barra de ferramentas';

  @override
  String get toolbarNavigationSection => 'Navegação da barra de ferramentas';

  @override
  String get toolbarNavigationHiddenBehavior => 'Itens ocultos';

  @override
  String get toolbarNavigationRemove => 'Ocultar completamente';

  @override
  String get toolbarNavigationMore => 'Mover para Mais';

  @override
  String get toolbarNavigationReorder =>
      'Reordenar itens da barra de ferramentas';

  @override
  String get toolbarNavigationVisibility =>
      'Mostrar item da barra de ferramentas';

  @override
  String get toolbarNavigationTimetable => 'Seletor de horário';

  @override
  String get toolbarNavigationWeek => 'Seletor de semana';

  @override
  String get toolbarNavigationView => 'Seletor de visualização';

  @override
  String get toolbarNavigationCategory => 'Seletor de categoria';

  @override
  String get toolbarNavigationDate => 'Seletor de data';

  @override
  String get generalToolbarWidthPolicy =>
      'Distribuição de espaço na barra de ferramentas';

  @override
  String get generalToolbarWidthContent => 'Distribuição automática';

  @override
  String get generalToolbarWidthBalanced => 'Equilibrada';

  @override
  String get generalToolbarWidthCalendarPriority => 'Prioridade da categoria';

  @override
  String get generalToolbarWidthDatePriority => 'Prioridade da data';

  @override
  String get generalViewSwitchCycle => 'Alternar entre visualizações';

  @override
  String get generalViewSwitchMenu => 'Abrir menu de visualizações';

  @override
  String get generalViewSwitchTooltip => 'Mudar visualização';

  @override
  String get generalViewSwitchMenuTooltip => 'Escolher visualização';

  @override
  String get generalViewLongPressTodayHint =>
      'Mantenha pressionado para ir para hoje';

  @override
  String get generalScheduleDisplaySection => 'Exibição da agenda';

  @override
  String get generalTimeGridSection => 'Grade de horários';

  @override
  String get generalPopupSection => 'Comportamento dos popups';

  @override
  String get quickActionsSection => 'Ações rápidas';

  @override
  String get showAddCourseFab =>
      'Mostrar botão flutuante para adicionar disciplinas';

  @override
  String get showAddCourseFabHint =>
      'Mostra ou oculta o botão flutuante para adicionar disciplinas no canto inferior direito do horário.';

  @override
  String get showAddEventFab =>
      'Mostrar botão flutuante para adicionar eventos';

  @override
  String get showAddEventFabHint =>
      'Mostra ou oculta o botão flutuante para adicionar eventos no canto inferior direito da agenda.';

  @override
  String get enableLongPressAddCourse =>
      'Manter pressionada uma área vazia para adicionar disciplinas';

  @override
  String get enableLongPressAddCourseHint =>
      'Mantenha pressionada uma área vazia da grade do horário para adicionar uma disciplina.';

  @override
  String get enableLongPressAddEvent =>
      'Manter pressionada uma área vazia para adicionar eventos';

  @override
  String get enableLongPressAddEventHint =>
      'Na visualização diária ou semanal, mantenha pressionada uma área vazia da grade de horários para adicionar um evento.';

  @override
  String get developerModeTitle => 'Modo de programador';

  @override
  String get developerModeDescription =>
      'Ferramentas para adicionar dados de exemplo completos e verificar o aspeto e as interações.';

  @override
  String get developerSampleLanguage => 'Idioma dos dados de exemplo';

  @override
  String get developerSampleChinese => 'Chinês';

  @override
  String get developerSampleEnglish => 'Inglês';

  @override
  String get developerSampleDataDescription =>
      'Adiciona um horário e um conjunto de categorias e eventos sem substituir os dados existentes.';

  @override
  String get developerAddSampleData => 'Adicionar dados de exemplo';

  @override
  String get developerSampleDataAdded =>
      'O horário e os eventos de exemplo foram adicionados.';

  @override
  String get developerModeLongPressHint =>
      'Prima durante 3 segundos para abrir o modo de programador';

  @override
  String get developerNotificationDiagnostics => 'Diagnóstico de notificações';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Verifique o estado de entrega no Android, reconstrua o plano de lembretes existente e envie notificações de teste seguras pelo serviço normal de notificações do Sked.';

  @override
  String get developerNotificationUnsupported =>
      'O diagnóstico de notificações está disponível apenas no Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'O diagnóstico de notificações estará disponível após o início do coordenador da agenda.';

  @override
  String get developerNotificationRefresh => 'Atualizar diagnóstico';

  @override
  String get developerNotificationSystemStatus =>
      'Permissão de notificações do sistema';

  @override
  String get developerNotificationPermissionAllowed => 'Permitida';

  @override
  String get developerNotificationPermissionBlocked => 'Bloqueada';

  @override
  String get developerNotificationExactAlarm => 'Alarmes exatos';

  @override
  String get developerNotificationExactAlarmAllowed => 'Permitidos';

  @override
  String get developerNotificationExactAlarmBlocked => 'Não permitidos';

  @override
  String get developerNotificationPlan => 'Plano de notificações da agenda';

  @override
  String get developerNotificationCoverage => 'Cobertura dos lembretes';

  @override
  String get developerNotificationCoverageReady =>
      'Todos os lembretes finitos conhecidos estão programados diretamente';

  @override
  String get developerNotificationCoverageRenewable =>
      'Os lembretes recorrentes são reprogramados a longo prazo na medida do possível';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'A capacidade de alarmes diretos está esgotada; os lembretes posteriores são reprogramados na medida do possível';

  @override
  String get developerNotificationCoverageBlocked =>
      'As condições para uma entrega precisa não foram atendidas';

  @override
  String get developerNotificationCoverageFailed =>
      'A última sincronização de lembretes falhou';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled alarmes diretos / capacidade: $capacity';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Último erro: $message';
  }

  @override
  String get developerNotificationTestChannel => 'Canal de teste';

  @override
  String get developerNotificationTestCourse => 'Lembretes de disciplinas';

  @override
  String get developerNotificationTestSchedule => 'Lembretes de eventos';

  @override
  String get developerNotificationImmediateTest => 'Enviar teste imediato';

  @override
  String get developerNotificationThirtySecondTest =>
      'Programar teste em segundo plano para daqui a 30 segundos';

  @override
  String get developerNotificationImmediateQueued =>
      'Notificação de teste imediato enviada.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Teste em segundo plano programado para daqui a 30 segundos.';

  @override
  String get developerNotificationAppSwitch =>
      'Controle de lembretes do aplicativo';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Ativado para lembretes normais';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Desativado para lembretes normais; os testes de desenvolvedor continuam disponíveis';

  @override
  String get developerNotificationTimeZone => 'Fuso horário local';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Ainda não foi criado. Um teste de desenvolvedor o criará.';

  @override
  String get developerNotificationChannelEnabledState => 'Ativado';

  @override
  String get developerNotificationChannelBlockedState => 'Bloqueado';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importância: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importância indisponível';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending pendentes / $active ativas';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Última exibição nativa: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Nenhuma reconciliação registrada ainda.';

  @override
  String get developerNotificationNextReminder => 'Próximo lembrete real';

  @override
  String get developerNotificationNoPendingReminder =>
      'Nenhum lembrete futuro no plano atual';

  @override
  String get developerNotificationNextRenewal =>
      'Próxima reprogramação sem garantia';

  @override
  String get developerNotificationLastSynchronization =>
      'Última sincronização de lembretes';

  @override
  String get developerNotificationLateRecovery =>
      'Recuperação de lembretes atrasados';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count lembretes foram recuperados após o horário original';
  }

  @override
  String developerNotificationReconciliationSummary(
    Object origin,
    Object mode,
    Object result,
    Object time,
  ) {
    return '$origin · $mode · $result · $time';
  }

  @override
  String get developerNotificationReconcileOriginForeground => 'Primeiro plano';

  @override
  String get developerNotificationReconcileOriginBackground => 'Segundo plano';

  @override
  String get developerNotificationReconcileModeAuthoritative => 'Autoritativa';

  @override
  String get developerNotificationReconcileModeRecovery => 'Recuperação';

  @override
  String get developerNotificationRunRecovery =>
      'Executar recuperação dos lembretes';

  @override
  String get developerNotificationRecoveryComplete =>
      'Recuperação de lembretes concluída';

  @override
  String get developerNotificationReconcileResultSuccess => 'Concluída';

  @override
  String get developerNotificationReconcileResultSkipped => 'Ignorada';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Bloqueada até que todas as condições de entrega precisa sejam atendidas';

  @override
  String get developerNotificationReconcileResultFailed => 'Falhou';

  @override
  String get developerNotificationBackgroundLimits =>
      'Limites de segundo plano do fabricante';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'As restrições de segundo plano do fabricante podem afetar a entrega.';

  @override
  String get developerNotificationAutostart =>
      'Inicialização em segundo plano do fabricante';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Fabricante: $vendor; há um acesso às configurações do fabricante. O Android não permite consultar o estado da autorização.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Fabricante: $vendor; serão usados os detalhes do aplicativo como alternativa. O Android não permite consultar o estado da autorização.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Não há acesso disponível às configurações de segundo plano do fabricante.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Último destino aberto: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'configurações do fabricante';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'detalhes do aplicativo';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'nenhum';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Limites da recuperação após reiniciar';

  @override
  String get developerNotificationRebootBoundary =>
      'A recuperação começa após o primeiro desbloqueio; um aplicativo interrompido à força não pode iniciar sozinho.';

  @override
  String get developerNotificationTestChecking =>
      'Os testes ficam indisponíveis enquanto o estado das notificações é verificado.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Os testes estão indisponíveis porque as notificações do sistema estão bloqueadas.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Os testes estão indisponíveis porque o canal de notificação selecionado está bloqueado.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Gerenciada pelas configurações de notificações do Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Não se aplica ao Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Identidade do pacote Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identidade MSIX disponível; as notificações exibidas podem ser removidas';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Instale a versão MSIX para remover com segurança as notificações exibidas';

  @override
  String get collapseWorkspaceNavigation =>
      'Recolher navegação do espaço de trabalho';

  @override
  String get expandWorkspaceNavigation =>
      'Expandir navegação do espaço de trabalho';

  @override
  String get schoolWebImportExitBrowser => 'Sair do navegador integrado';

  @override
  String get schoolWebImportEditAddress => 'Editar endereço';

  @override
  String get schoolWebImportAddressLabel => 'Endereço web';

  @override
  String get schoolWebImportOpenAddress => 'Abrir';

  @override
  String get schoolWebImportAddressInvalid =>
      'Insira um endereço HTTP ou HTTPS com um host.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Esta página solicitou uma nova janela que não pode ser aberta neste dispositivo.';

  @override
  String get schoolWebImportSecureConnection => 'Conexão segura';

  @override
  String get schoolWebImportInsecureConnection => 'Conexão não segura';

  @override
  String get notificationSettingsSection => 'Lembretes e notificações';

  @override
  String get notificationCoverage => 'Cobertura dos lembretes';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Review the system requirements below.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

  @override
  String get notificationCoverageRenewable =>
      'Eventos recorrentes sem data de término são reprogramados em segundo plano para manter a cobertura a longo prazo.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'O Android pode programar diretamente até $capacity lembretes; os posteriores são reprogramados antecipadamente quando possível.';
  }

  @override
  String get notificationSettingsEnabled => 'Ativar lembretes e notificações';

  @override
  String get notificationSettingsEnabledHint =>
      'Programa apenas itens com um lembrete. Defina abaixo um lembrete padrão para as disciplinas que o herdam.';

  @override
  String get notificationPrecisionLimitations =>
      'Os lembretes dependem das permissões e da execução em segundo plano. Desligamentos, mudanças de hora ou restrições do sistema podem atrasá-los.';

  @override
  String get notificationSettingsEnabledSummary => 'Ativado';

  @override
  String get notificationSettingsDisabledSummary => 'Desativado';

  @override
  String get notificationDefaultsSection => 'Lembretes padrão';

  @override
  String get notificationCourseDefaultReminder =>
      'Lembrete padrão de disciplinas';

  @override
  String get notificationGeneralDefaultReminder => 'Lembrete padrão de eventos';

  @override
  String get notificationReminderOff => 'Sem lembrete';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutos antes';
  }

  @override
  String get notificationPermission => 'Permissão de notificações';

  @override
  String get notificationPermissionGranted => 'Permitida pelo sistema';

  @override
  String get notificationPermissionDenied => 'Bloqueada pelo sistema';

  @override
  String get notificationPermissionChecking => 'Verificando permissão…';

  @override
  String get notificationPermissionRequest => 'Solicitar permissão';

  @override
  String get notificationPermissionOpenSettings =>
      'Abrir configurações do sistema';

  @override
  String get notificationPermissionRequestFailed =>
      'Não foi possível consultar a permissão de notificações. Tente novamente.';

  @override
  String get notificationExactAlarm => 'Permissão de alarmes exatos';

  @override
  String get notificationExactAlarmAllowed => 'Permitida pelo sistema';

  @override
  String get notificationExactAlarmRequired =>
      'Necessária para lembretes em horários precisos';

  @override
  String get notificationExactAlarmRequest => 'Permitir alarmes exatos';

  @override
  String get notificationBatteryOptimization => 'Otimização de bateria';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Isento da otimização de bateria do Android';

  @override
  String get notificationBatteryOptimizationWarning =>
      'Battery optimization or vendor background restrictions may delay reminders. You can adjust these in system settings.';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Abrir configurações de otimização de bateria';

  @override
  String get notificationAutostart =>
      'Inicialização em segundo plano do fabricante';

  @override
  String get notificationAutostartVendorHint =>
      'Permita a inicialização automática ou a execução em segundo plano para restaurar os lembretes após reiniciar.';

  @override
  String get notificationAutostartFallbackHint =>
      'Abra os detalhes do Sked e permita a execução em segundo plano. O Android não consegue verificar esta configuração do fabricante.';

  @override
  String get notificationAutostartUnavailable =>
      'Nenhuma página de configurações do fabricante foi encontrada. Verifique os detalhes do Sked manualmente.';

  @override
  String get notificationAutostartRequest =>
      'Abrir configurações de segundo plano do fabricante';

  @override
  String get notificationAutostartOpenFailed =>
      'Não foi possível abrir as configurações de segundo plano do fabricante. Verifique os detalhes do Sked manualmente.';

  @override
  String get notificationLockScreenTitles => 'Mostrar títulos nas notificações';

  @override
  String get notificationLockScreenTitlesHint =>
      'Também se aplica à tela de bloqueio. Quando desativado, apenas o tipo e o horário são incluídos.';

  @override
  String get notificationPlatformUnsupported =>
      'Esta plataforma não oferece notificações nativas.';

  @override
  String get workspaceFeatures => 'Gestão de funcionalidades';

  @override
  String get workspaceBoth => 'Horário e agenda';

  @override
  String get workspaceOnlyStudent => 'Apenas horário';

  @override
  String get workspaceOnlyGeneral => 'Apenas agenda';

  @override
  String get workspaceDisableTitle => 'Desativar este espaço?';

  @override
  String get workspaceDisableMessage =>
      'Os dados e as preferências serão mantidos. As funcionalidades e os lembretes serão suspensos até que volte a ativá-lo aqui.';

  @override
  String get workspaceEnableHint =>
      'Escolha as funcionalidades que utiliza. Pelo menos uma deve permanecer ativa.';

  @override
  String get workspaceLastRequired =>
      'Pelo menos um espaço deve permanecer ativo.';

  @override
  String get workspaceReminderCleanupFailed =>
      'O espaço está desativado, mas não foi possível remover os lembretes. Tente novamente a recuperação de notificações.';

  @override
  String get settingsDataPrivacy => 'Dados e privacidade';

  @override
  String get selectedDayAgenda => 'Dia selecionado';

  @override
  String get notificationTroubleshooting =>
      'Permissões e resolução de problemas';

  @override
  String get settingsConnection => 'Ligação';

  @override
  String get settingsAdvanced => 'Avançado';

  @override
  String get unsavedChangesMessage =>
      'Existem alterações não guardadas. Descartá-las e sair?';

  @override
  String get backupWorkspaceSelection =>
      'A cópia de segurança completa inclui os dados e a seleção dos espaços ativos.';

  @override
  String get assistantLayoutPreview => 'IA · Prévia do layout';

  @override
  String get assistantSelectionContext => 'Usa a seleção atual como contexto';

  @override
  String get assistantPreviewDescription =>
      'Discuss and work in the current workspace. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Rascunho da mensagem';

  @override
  String get assistantPreviewNoSend =>
      'Apenas uma prévia do layout. Nada será enviado ou alterado.';

  @override
  String get resizePanel => 'Redimensionar painel';

  @override
  String get minimizeWindow => 'Minimizar';

  @override
  String get maximizeWindow => 'Maximizar';

  @override
  String get restoreWindow => 'Restaurar janela';

  @override
  String get closeWindow => 'Fechar janela';

  @override
  String get courseSystemReminder => 'Lembrete do sistema';

  @override
  String courseReminderInherit(String reminder) {
    return 'Usar padrão ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Os lembretes do sistema estão desativados nas configurações de notificações. Esta preferência da disciplina ainda pode ser salva.';

  @override
  String get courseReminderDefaultOff =>
      'Nenhum lembrete padrão foi definido para disciplinas. Escolha um lembrete personalizado aqui ou defina um padrão nas configurações de notificações.';

  @override
  String get courseReminderDeliveryHint =>
      'Esta preferência é salva com a disciplina. A entrega depende das permissões de notificação do sistema e das restrições de segundo plano.';

  @override
  String get courseReminderPermissionUnknown =>
      'O estado das notificações do sistema não foi verificado. Revise as configurações de notificações antes de depender dos lembretes.';

  @override
  String get courseReminderMinutesLabel => 'Minutos antes da aula';

  @override
  String get exportAction => 'Exportar';

  @override
  String get datePickerSelectWeek => 'Selecionar semana';

  @override
  String get datePickerSelectMonth => 'Selecionar mês';

  @override
  String get generalDateLabelFormatDescription =>
      'Aplica-se à navegação por datas no computador e em telas menores.';

  @override
  String get dateRangeTitle => 'Escolher intervalo de datas';

  @override
  String get dateRangeCustom => 'Personalizado';

  @override
  String get dateRangeChooseStart => 'Escolha a data inicial';

  @override
  String get dateRangeChooseEnd => 'Escolha a data final';

  @override
  String get dateRangeLimit =>
      'Selecione de 1 a 14 dias, incluindo as duas datas.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    return 'Personalizado · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Selecionar com rodas de rolagem';

  @override
  String get courseReminderUseDefault => 'Usar padrão';

  @override
  String get courseReminderInvalidMinutes =>
      'Digite um número inteiro de minutos maior ou igual a zero.';

  @override
  String get generalCustomColumnWidth =>
      'Largura das colunas da visualização personalizada';

  @override
  String get generalCustomColumnWidthAuto => 'Automática';

  @override
  String get generalCustomColumnWidthManual => 'Largura mínima';

  @override
  String get generalCustomColumnWidthMinimum => 'Largura mínima por dia';

  @override
  String get generalCustomColumnWidthHint =>
      'Todas as datas compartilham esta largura mínima. As colunas preenchem o espaço disponível ou rolam horizontalmente. Afeta apenas a visualização personalizada.';

  @override
  String get settingsAppearanceLanguage => 'Aparência e idioma';

  @override
  String get settingsAppearanceDetails => 'Cores e contornos';

  @override
  String get monthNoEvents => 'Nenhum evento neste dia';

  @override
  String get settingsOverview => 'Visão geral';

  @override
  String get settingsThemeTarget => 'Tema para';

  @override
  String get settingsColorMode => 'Modo de cor';

  @override
  String get settingsNotificationPreferences => 'Preferências de lembretes';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Lembretes padrão, permissões e confiabilidade';

  @override
  String get settingsFeaturesSummary => 'Espaços de trabalho e navegação';

  @override
  String get settingsPrivacySummary =>
      'Política de privacidade e limpeza de dados locais';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count períodos',
      one: '$count período',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Período';

  @override
  String get periodTimesDurationColumn => 'Duração';

  @override
  String get periodTimesGapColumn => 'Intervalo';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Aguardando para salvar…';

  @override
  String get periodTimesSaveFailed => 'Não salvo · Falha ao salvar';

  @override
  String get periodTimesInvalidStatus =>
      'Não salvo · Corrija os horários destacados';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'O Sked não conseguiu confirmar se a última gravação foi revertida. A escrita está suspensa e as cópias de recuperação foram preservadas. Verifique o armazenamento e tente carregar novamente.';

  @override
  String get settingsPanelDisplayMode => 'Exibição dos painéis';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Compartilhada por horários e agendas';

  @override
  String get settingsPanelDisplayOverlay => 'Sobreposição';

  @override
  String get settingsPanelDisplaySideBySide => 'Lado a lado';

  @override
  String get settingsPanelDisplayAutomatic => 'Automática';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Sobrepõe o lado direito sem redimensionar o calendário.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Prioriza lado a lado; sobrepõe apenas se o calendário ficar estreito demais.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Exibe lado a lado quando o calendário mantém uma largura legível; caso contrário, sobrepõe.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Desativar Configurações ou Espaço de trabalho na barra de ferramentas move o item para Mais, em vez de removê-lo. Mais não pode ser ocultado enquanto contiver ações essenciais. A troca de espaço de trabalho aparece apenas quando a navegação inferior está oculta e vários espaços de trabalho estão ativados.';

  @override
  String get reminderEnded => 'Encerrado';

  @override
  String get reminderAutoCloseHint =>
      'Fecha após 10 segundos. Interaja para manter aberto.';

  @override
  String get showReminderIndependently => 'Abrir separadamente';

  @override
  String get categoryManagerTitle => 'Gerenciar categorias';

  @override
  String get categoryHidden => 'Oculta';

  @override
  String get categoryShowOnCalendar => 'Mostrar no calendário';

  @override
  String get categoryHideOnCalendar => 'Ocultar do calendário';

  @override
  String get categoryEditColor => 'Alterar cor da categoria';

  @override
  String get categoryThemePalette => 'Paleta do tema';

  @override
  String get categoryCustomColor => 'Personalizada';

  @override
  String get colorHexInvalid => 'Digite uma cor hexadecimal de seis dígitos.';

  @override
  String get colorPickerHue => 'Matiz';

  @override
  String get colorPickerSaturation => 'Saturação';

  @override
  String get colorPickerValue => 'Brilho';

  @override
  String get colorPickerHex => 'Cor hexadecimal';

  @override
  String get colorPickerSpectrum => 'Espectro de cores';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'Use as setas para a esquerda e para a direita para ajustar a saturação, e para cima e para baixo para ajustar o brilho.';

  @override
  String categoryColorSlot(int number) {
    return 'Cor do tema $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'As atualizações da loja podem chegar mais tarde. A disponibilidade é indicada na página da loja.';

  @override
  String get storePrereleaseNotice =>
      'Receber avisos de atualizações de pré-lançamento não inscreve você em um programa de testes da loja.';

  @override
  String get updateFoundTitle => 'Nova versão disponível';

  @override
  String get updateNoNotes => 'Nenhuma nota de versão foi fornecida.';

  @override
  String get updateLater => 'Mais tarde';

  @override
  String get updateRetry => 'Tentar novamente';

  @override
  String get updatePrerelease => 'Pré-lançamento';

  @override
  String get updateNetworkFailure =>
      'Não foi possível verificar atualizações. Verifique sua conexão e tente novamente.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Nenhuma versão mais recente encontrada (atual: $version)';
  }

  @override
  String get backupRestoreInProgressTitle =>
      'A restaurar a cópia de segurança…';

  @override
  String get backupRestoreInProgressMessage =>
      'Poderá alterar os dados e as definições quando o restauro terminar. Pode continuar a consultá-los.';

  @override
  String get managePeriodTimeSets => 'Gerenciar conjuntos de horários de aula';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'Períodos: $periodCount · Horários associados: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'Importe como um novo horário ou substitua todas as informações e aulas do horário “$name”.';
  }

  @override
  String get selectAtLeastOneWeek => 'Selecione pelo menos uma semana.';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'Manter lembretes de categorias ocultas';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'Aplica-se aos lembretes no aplicativo e às notificações do sistema. As notificações do sistema também precisam estar ativadas nas configurações.';

  @override
  String get generalReminderFollowDefault => 'Usar padrão';

  @override
  String get generalReminderCustom => 'Lembretes personalizados';

  @override
  String get eventEditScopeTitle => 'Editar evento recorrente';

  @override
  String get eventEditThisOccurrence => 'Somente esta ocorrência';

  @override
  String get eventEditThisAndFollowing => 'Esta e as próximas ocorrências';

  @override
  String get eventEditEntireSeries => 'Toda a série';

  @override
  String get eventEditEntireSeriesHint =>
      'As alterações se aplicam a toda a série, incluindo ocorrências passadas.';

  @override
  String get eventEditConflict =>
      'Este evento foi alterado. Seu rascunho foi mantido; reabra o evento para conferir a versão mais recente.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'Salvo na categoria oculta “$name”.';
  }

  @override
  String get viewEvent => 'Ver evento';

  @override
  String get schoolSitesNameRequired => 'Introduza o nome da escola.';

  @override
  String get schoolSitesLoginUrlRequired =>
      'Introduza um URL de início de sessão.';

  @override
  String get languageNoResults => 'Nenhum idioma correspondente';

  @override
  String get themeGeneralMonthTextColors => 'Texto da vista mensal';

  @override
  String get themeGeneralFestivalTextColor => 'Festas e feriados';

  @override
  String get themeGeneralSolarTermTextColor => 'Períodos solares';

  @override
  String get themeGeneralLunarTextColor => 'Datas lunares';

  @override
  String get courseTextLowContrastHint =>
      'Esta cor de texto pode ser difícil de ler em alguns cartões de cursos (contraste inferior a 4.5:1). Pode mantê-la ou escolher outra.';

  @override
  String get shortenSemesterTitle => 'Encurtar o semestre?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'O semestre terminará na semana $weeks. Cursos com aulas posteriores: $count. Os cursos e as semanas selecionadas serão mantidos. Restaure o número de semanas para voltar a vê-los.';
  }

  @override
  String get defaultGeneralCalendarName => 'O meu calendário';

  @override
  String get icsImportReportTitle => 'Relatório de importação';

  @override
  String get icsImportReportAction => 'Ver relatório';

  @override
  String get icsExportFailureTitle => 'Não é possível exportar como ICS';

  @override
  String get icsCopyDiagnosticsAction => 'Copiar detalhes';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'Este ICS contém fusos horários com nome que o Sked não consegue interpretar com segurança. Nada foi importado. Exporte UTC ou horas locais sem fuso horário do calendário de origem e tente novamente.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'Este evento mensal não pode ser representado com precisão em ICS. Exporte JSON para preservar as datas.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'Este evento recorrente não tem ocorrências válidas para exportação em ICS. Exporte JSON para preservar o registo.';

  @override
  String get icsImportedCalendarName => 'Calendário importado';

  @override
  String get icsUntitledEventName => 'Evento sem título';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'O Windows só agenda lembretes para os próximos $days dias, até $capacity de cada vez. Volte a abrir a aplicação regularmente para atualizar o plano.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'Lembretes agendados: $count. A última verificação abrange o período até $date.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'O limite de lembretes foi atingido. Alguns ainda não estão agendados. Volte a abrir a aplicação depois de os próximos lembretes serem apresentados para atualizar o plano.';

  @override
  String get courseInactiveThisWeek => 'Não está agendado para esta semana';

  @override
  String get courseInactiveBadge => 'Off week';

  @override
  String get schoolWebImportSignOut => 'Sign out';

  @override
  String get schoolWebImportSignOutTitle => 'Sign out of school websites?';

  @override
  String get schoolWebImportSignOutMessage =>
      'This clears sign-in cookies and saved website data for school pages in Sked. Imported timetables and app settings are kept.';

  @override
  String get schoolWebImportSignOutSuccess =>
      'School website sign-in data cleared.';

  @override
  String get schoolWebImportSignOutFailed =>
      'Could not clear school sign-in data. Please try again.';

  @override
  String importWarningSkippedUnsupportedTimeZone(Object fields) {
    return 'Skipped an event whose time zone cannot be interpreted safely: $fields.';
  }

  @override
  String get expandTimelineEvents => 'Expand events';

  @override
  String get timelineEvents => 'Events in this timeline';

  @override
  String get schoolImportEndpointChangeTitle => 'Change the parsing endpoint?';

  @override
  String schoolImportEndpointChangeMessage(String previous, String next) {
    return 'The saved API key will be sent to the new endpoint when you parse a timetable or fetch models.\n\nCurrent: $previous\nNew: $next\n\nOnly continue if you trust the new endpoint.';
  }

  @override
  String get schoolImportEndpointChangeConfirm => 'Change endpoint';

  @override
  String restoreBackupParserSettingsSummary(String current, String backup) {
    return 'The parsing endpoint, model and prompt on this device are kept. The API key on this device will be cleared.\n\nKept endpoint: $current\nBackup endpoint (ignored): $backup';
  }

  @override
  String get backupParserEndpointUnset => 'Not configured';

  @override
  String get periodTimesDayFull =>
      'No room remains for another period today. Adjust the existing times before adding more.';

  @override
  String get importWarningRecurrenceDateClamped =>
      'The repeat rule was kept. Dates missing from a month move to its last day; the source rule skips those dates. These moved dates count toward the repeat limit.';

  @override
  String importWarningSkippedRecurrenceOverride(Object fields) {
    return 'Skipped a recurrence override whose original occurrence could not be identified safely: $fields.';
  }

  @override
  String get importWarningSkippedCancelledEvent => 'Skipped a cancelled event.';

  @override
  String get importWarningSkippedEmptyRecurrence =>
      'Skipped a recurring event because UNTIL is before its first occurrence.';

  @override
  String importTextFileTooLarge(Object size) {
    return 'Text files must be $size MB or smaller.';
  }

  @override
  String icsImportReviewNotice(Object count, Object warningCount) {
    return 'Ready to import $count events with $warningCount warnings. Review all skipped events and changes below. Nothing has been saved yet.';
  }

  @override
  String get icsImportContinueAction => 'Continue import';

  @override
  String importWarningRecurrenceRuleDowngraded(Object fields) {
    return 'This event will be imported as a single event. Unsupported fields or rule parts: $fields.';
  }

  @override
  String get notificationSnoozeAction => 'Adiar 10 minutos';

  @override
  String get notificationHandledAction => 'Marcar como tratado';

  @override
  String get developerTestNotificationTitle => 'Notificação de teste do Sked';

  @override
  String get developerTestNotificationCourseBody =>
      'O canal de lembretes de cursos está a funcionar.';

  @override
  String get developerTestNotificationScheduleBody =>
      'O canal de lembretes de eventos está a funcionar.';

  @override
  String get eventRecurrenceExceptionsChangeTitle => 'Change repeat pattern?';

  @override
  String get eventRecurrenceExceptionsChangeMessage =>
      'Previously skipped dates stay skipped only if the new repeat pattern still has an occurrence on that date. Other skip records will be removed. Turning repeats off removes all skip records. Events edited separately stay unchanged.';
}
