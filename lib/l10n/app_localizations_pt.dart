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
  String get schoolImportResultEditorTitle => 'Editar resultado analisado';

  @override
  String get schoolImportParsePageTitle => 'Analisar horário';

  @override
  String get schoolImportParsePageParsing => 'Analisando…';

  @override
  String get schoolImportParsePageFailed => 'Falha na análise';

  @override
  String get schoolImportParsePageComplete => 'Análise concluída';

  @override
  String get schoolImportParsePageContinue => 'Continuar';

  @override
  String get schoolImportParsePageRawContent => 'Resposta bruta';

  @override
  String get schoolImportParsePageExpandRaw => 'Expandir resposta bruta';

  @override
  String get schoolImportParsePageCollapseRaw => 'Recolher resposta bruta';

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
      'Crie um horário ou importe um de um arquivo JSON.';

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
  String get settingsSectionTimetable => 'Horário';

  @override
  String get settingsSectionGeneralSchedule => 'Agenda';

  @override
  String get settingsSectionAppearance => 'Aparência';

  @override
  String get settingsSectionApp => 'Aplicativo';

  @override
  String get settingsSectionWorkspace => 'Espaço de trabalho';

  @override
  String get settingsSectionAppearanceLanguage => 'Aparência e idioma';

  @override
  String get settingsSectionDataSecurity => 'Dados e segurança';

  @override
  String get settingsSectionAbout => 'Sobre o Sked';

  @override
  String get noTimetableSettings =>
      'Nenhum horário está disponível no momento para configurações.';

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
  String get showTimetableGridLinesHint =>
      'Controla se as linhas horizontais e verticais da grade ficam visíveis no horário.';

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
  String get fitWeekColumnsToWidthHint =>
      'Mostra as sete colunas do horário na tela quando possível. Desative para usar uma largura fixa e rolar.';

  @override
  String get enableWeekSwipeNavigation => 'Deslizar para mudar de semana';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Deslize para a esquerda ou direita para mudar de semana. Com larguras fixas, arraste primeiro além da borda.';

  @override
  String get liveCourseOutlineColor => 'Cor do contorno da disciplina';

  @override
  String get liveCourseOutlineColorHint =>
      'Escolha se os contornos destacam a disciplina atual/próxima ou todas as disciplinas exibidas na página atual.';

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
  String get languagePageDescription =>
      'Escolha um dos idiomas que realmente estão disponíveis no app.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Resposta da API';

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
  String get appBackupSubtitle =>
      'Faça backup ou restaure horários, agendas, configurações e sites escolares. As chaves de API não são incluídas.';

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
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates =>
      'As atualizações são geridas pela Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Receber versões de pré-lançamento';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Incluir versões Alpha, Beta e RC, que podem ser instáveis. Quando desativado, apenas versões estáveis são oferecidas.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Já está na versão mais recente ($version)';
  }

  @override
  String get currentVersionLabel => 'Versão atual';

  @override
  String get newVersionAvailable => 'Atualização disponível';

  @override
  String get latestVersionLabel => 'Versão mais recente';

  @override
  String get updateContentLabel => 'Detalhes da atualização';

  @override
  String get officialWebsite => 'Site oficial';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Nuvem';

  @override
  String get ignoreThisVersion => 'Ignorar esta versão';

  @override
  String get openUpdatesFailed =>
      'Não foi possível abrir o link de atualização';

  @override
  String get updateCheckFailedTitle => 'Falha ao verificar atualizações';

  @override
  String get updateCheckFailedMessage =>
      'Não foi possível obter a versão mais recente do GitHub. Você ainda pode abrir a página de versões do GitHub abaixo.';

  @override
  String get githubRepository => 'Repositório no GitHub';

  @override
  String get googlePlayStoreDesc => 'Ver o Sked no Google Play';

  @override
  String get openGooglePlayFailed => 'Não foi possível abrir o Google Play';

  @override
  String get starSkedOnGithub => 'Dê uma estrela ao Sked no GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Abra o repositório do projeto e dê uma estrela ao Sked';

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
  String get share => 'Compartilhar';

  @override
  String get selectTimetablesToExport => 'Escolher horários para exportar';

  @override
  String get selectTimetablesToImport => 'Escolher horários para importar';

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
      'O Sked é uma ferramenta de horários com foco local. Os horários, conjuntos de períodos e configurações de sites escolares são armazenados apenas no seu dispositivo ou navegador e nunca são enviados automaticamente. O app só processa dados quando você aciona explicitamente ações como importar, analisar páginas web, compartilhar ou abrir links externos. A política de privacidade completa está disponível online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Armazenamento local';

  @override
  String get privacyPolicyLocalStorageBody =>
      'Nas plataformas nativas, o Sked armazena horários, agendas, configurações relacionadas e configurações editáveis de sites escolares no diretório de suporte a aplicativos do sistema operacional; a versão web usa o armazenamento do navegador. Os arquivos gravados por versões anteriores na pasta Documentos do usuário permanecem no local, mas não são lidos nem migrados automaticamente. Para manter esses dados, exporte um backup completo pela versão antiga antes de atualizar e restaure-o depois. As configurações da API de IA são armazenadas localmente; a chave de API personalizada é guardada no armazenamento seguro da plataforma quando disponível. Os backups completos não incluem a chave de API personalizada. O aplicativo não envia automaticamente esses dados locais a um servidor controlado pelo desenvolvedor.';

  @override
  String get privacyPolicyImportExportTitle => 'Importação e exportação';

  @override
  String get privacyPolicyImportExportBody =>
      'O app lê ou grava arquivos JSON de horário, arquivos JSON de sites escolares e arquivos de modelo de períodos somente quando você escolhe explicitamente um arquivo ou inicia uma ação de exportação. Importar esses arquivos é uma operação local, a menos que você também escolha a análise de página web. Buscar uma lista de modelos personalizados também é uma ação de rede explícita e contata apenas o endpoint personalizado que você configurou.';

  @override
  String get privacyPolicySharingTitle => 'Compartilhamento';

  @override
  String get privacyPolicySharingBody =>
      'Quando você usa o compartilhamento explicitamente, o app passa o arquivo exportado para a folha de compartilhamento do sistema ou para o app de destino que você escolher. Como esse arquivo será tratado depois disso depende do app ou serviço de destino selecionado.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Links externos';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Quando você abre links externos, como o repositório do GitHub, o app entrega essa ação ao seu navegador ou a outro aplicativo externo. O tratamento de dados a partir desse ponto é regido pelo terceiro que você abrir.';

  @override
  String get privacyPolicyNoCollectionTitle => 'O que o app não coleta';

  @override
  String get privacyPolicyNoCollectionBody =>
      'O app não exige uma conta do Sked e não ativa análise, identificadores de publicidade nem backup em nuvem. Ele também não fornece um campo dedicado para coletar senhas de contas escolares. Se você entrar em um site escolar dentro do app, essa interação acontece na página escolar que você abriu.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Análise de página web';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Quando você usa a importação de uma página escolar ou analisa texto de horário / HTML colado, o app primeiro prepara e limpa o conteúdo localmente e depois envia o texto do horário, texto da página ou conteúdo HTML enviado, o título e URL opcionais da página, o idioma atual do app e o conteúdo do prompt do analisador para o endpoint compatível com OpenAI que você configurou. A busca da lista de modelos também solicita esse mesmo endpoint. O Sked não fornece um endpoint de análise integrado e não envia solicitações de análise para um backend de análise de horários controlado pelo desenvolvedor. O endpoint personalizado e quaisquer serviços upstream podem armazenar, encaminhar, limitar, excluir ou processar os dados de outra forma conforme as regras do provedor de serviço que você escolher. Se você usar uma Base URL http://, use-a apenas em dispositivos, redes e serviços de endpoint confiáveis, porque o conteúdo e as chaves de API podem não estar protegidos por criptografia de transporte.';

  @override
  String get privacyPolicyUpdatesTitle => 'Atualizações da política';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'A versão atual da política de privacidade é $version. Se uma versão posterior alterar como os dados são tratados, o app poderá pedir que você leia e concorde novamente com a política atualizada.';
  }

  @override
  String get privacyGateTitle =>
      'Concorde com a política de privacidade antes de usar o app';

  @override
  String get privacyGateSummaryStorage =>
      'Horários, conjuntos de horários dos períodos e configurações de sites escolares são armazenados apenas localmente e não são enviados automaticamente para um servidor do desenvolvedor.';

  @override
  String get privacyGateSummaryImportExport =>
      'Importação, exportação e compartilhamento só acontecem quando você os inicia explicitamente; a análise de página web envia apenas o conteúdo compactado que você enviar ao endpoint configurado, e você pode revisar o horário analisado antes de salvar.';

  @override
  String get privacyGateSummaryUpdates =>
      'Se uma versão posterior alterar como os dados são tratados, o app poderá pedir que você revise novamente a política de privacidade atualizada.';

  @override
  String get schoolWebImportEntry => 'Importar da página web da escola';

  @override
  String get schoolWebImportEntryDesc =>
      'Importe a página atual do horário a partir do site da escola.';

  @override
  String get schoolSitesManageEntry => 'Gerenciar sites escolares';

  @override
  String get schoolSitesManageEntryDesc =>
      'Adicione, edite e exclua URLs de login escolar, com importação e exportação em JSON.';

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
  String get schoolHtmlImportUrlLabel => 'URL de origem (opcional)';

  @override
  String get schoolHtmlImportTitleLabel => 'Título da página (opcional)';

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
  String get schoolHtmlImportCompressFirst => 'Prepare o conteúdo primeiro.';

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
  String get schoolWebImportPageTitle => 'Importação da página web da escola';

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
  String get schoolWebImportParserUsed => 'Analisador';

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
  String get schoolWebImportConfigMissing =>
      'A configuração do analisador personalizado está incompleta. Preencha primeiro a URL base, a chave de API e o modelo.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Esta plataforma ainda não oferece suporte para login web incorporado. Use uma plataforma com suporte a WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Escolher escola';

  @override
  String get schoolWebImportNoSchools =>
      'Nenhuma configuração de escola está disponível. Verifique primeiro o school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Falha ao carregar a configuração da escola. Verifique o formato do arquivo JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importar página atual';

  @override
  String get schoolWebImportLoadingPage => 'Carregando página…';

  @override
  String get schoolWebImportParsing => 'Analisando a página atual…';

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
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Analisador personalizado compatível com OpenAI';

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
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Analisador: personalizado ($model)';
  }

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
      'Não há horário atual para substituir.';

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
  String get firstLaunchTitle => 'Escolha o modo inicial';

  @override
  String get firstLaunchSubtitle =>
      'Escolha o espaço de trabalho que você mais usa. Você pode trocar de modo depois.';

  @override
  String get firstLaunchStudentDesc =>
      'Gerencie horários, cursos, semanas, períodos e importações.';

  @override
  String get firstLaunchGeneralDesc =>
      'Gerencie categorias, eventos, lembretes e dados JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Começar com horário';

  @override
  String get firstLaunchStartGeneral => 'Começar com agenda';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Ao escolher um espaço de trabalho inicial, você confirma que leu e aceita a ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Política de privacidade';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Alternar modo';

  @override
  String get generalScheduleComingSoon => 'Agenda disponível em breve';

  @override
  String get switchToStudentTimetable => 'Mudar para o horário';

  @override
  String get mySchedule => 'Minha agenda';

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
  String get recurrenceNoEndDate => 'Sem data de término';

  @override
  String get recurrenceSetEndDate => 'Definir';

  @override
  String get recurrenceChangeEndDate => 'Alterar';

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
  String get searchEvents => 'Buscar eventos';

  @override
  String get clearSearch => 'Limpar busca';

  @override
  String get filterByColor => 'Filtrar por cor';

  @override
  String get allColors => 'Todas as cores';

  @override
  String upcomingEventsCount(int count) {
    return 'Próximos: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Em atraso: $count';
  }

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
  String get reminder => 'Lembrete no aplicativo';

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
  String get reminderOverdue => 'Em atraso';

  @override
  String get generalFitWeekColumnsToWidth => 'Ajustar a semana ao ecrã';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Mostra a semana inteira em disposições compactas. Desative para deslocar horizontalmente. Os intervalos personalizados com mais de 7 dias continuam a permitir deslocação.';

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
    return 'Os campos ICS não compatíveis foram adicionados às notas: $fields';
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
  String get settingsWorkspaceMode => 'Espaço de trabalho ativo';

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
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled programados, $planned planejados';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Último erro: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Reconstruir o plano de notificações';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Plano de notificações reconstruído.';

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
  String get developerNotificationNextMaintenance => 'Próxima manutenção';

  @override
  String get developerNotificationNextRenewal =>
      'Próxima reprogramação sem garantia';

  @override
  String get developerNotificationNoMaintenance => 'Não programada';

  @override
  String get developerNotificationTruncation => 'Limitação do plano';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count omitidos pelo limite do plano';
  }

  @override
  String get developerNotificationLastReconciliation => 'Última reconciliação';

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
  String get developerNotificationReconcileModeMaintenance => 'Manutenção';

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
  String get schoolWebImportSignInConsentTitle =>
      'Abrir o início de sessão da escola?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'O início de sessão da escola pode enviar credenciais através de formulários ou redirecionamentos do servidor para a escola e os respetivos fornecedores de autenticação. O Android não consegue pausar cada transferência deste tipo para confirmar o destino separadamente. Continue apenas se confiar nestas entidades durante esta sessão de importação:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Abrir um início de sessão escolar não seguro?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Este início de sessão escolar utiliza HTTP. Qualquer pessoa que consiga observar ou alterar esta ligação poderá ler ou modificar as suas credenciais e o conteúdo da página. Continue apenas se aceitar este risco para:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Lembretes e notificações';

  @override
  String get notificationCoverage => 'Cobertura dos lembretes';

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
  String get notificationBatteryOptimizationRequired =>
      'Lembretes precisos exigem uma exceção à otimização de bateria do Android';

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
  String get notificationLockScreenTitles =>
      'Mostrar títulos na tela de bloqueio';

  @override
  String get notificationLockScreenTitlesHint =>
      'Quando desativado, os detalhes das notificações ficam privados na tela de bloqueio.';

  @override
  String get notificationWidgets => 'Widgets da tela inicial';

  @override
  String get notificationWidgetsDesc =>
      'Atualize os widgets do Sked e saiba como adicionar um pela tela inicial.';

  @override
  String get notificationWidgetsDialogTitle => 'Adicionar um widget do Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Na tela inicial do dispositivo, mantenha pressionada uma área vazia, escolha Widgets e adicione um widget do Sked. Ele mostra suas próximas disciplinas ou eventos.';

  @override
  String get notificationWidgetsRefresh => 'Atualizar widgets';

  @override
  String get notificationWidgetsRefreshed => 'Widgets atualizados';

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
  String get settingsSearch => 'Pesquisar definições';

  @override
  String get settingsNoResults => 'Nenhuma definição correspondente';

  @override
  String get settingsDataPrivacy => 'Dados e privacidade';

  @override
  String get workspacePreferences => 'Visualização e interação';

  @override
  String get workspaceManage => 'Gerir';

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
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

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
      one: '1 período',
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
}
