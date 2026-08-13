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
  String get createTimetable => 'Novo horário';

  @override
  String get jumpToWeek => 'Ir para a semana';

  @override
  String get timetable => 'Horário';

  @override
  String get timetableName => 'Nome do horário';

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
  String get settingsSectionTimetable => 'Timetable';

  @override
  String get settingsSectionGeneralSchedule => 'General schedule';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionWorkspace => 'Workspace';

  @override
  String get settingsSectionAppearanceLanguage => 'Appearance & language';

  @override
  String get settingsSectionDataSecurity => 'Data & security';

  @override
  String get settingsSectionAbout => 'About Sked';

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
  String get timetableHorizontalLayoutSection =>
      'Horizontal layout and gestures';

  @override
  String get fitDaySelectorToWidth => 'Fit day selector to screen';

  @override
  String get fitDaySelectorToWidthHint =>
      'Show all seven days within the screen when possible; turn off to use a fixed width and scroll.';

  @override
  String get fitWeekColumnsToWidth => 'Fit week columns to screen';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Show all seven timetable columns within the screen when possible; turn off to use a fixed width and scroll.';

  @override
  String get enableWeekSwipeNavigation => 'Swipe to change weeks';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Swipe left or right to move to another week. With fixed widths, drag past the edge first.';

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
      'Uma restauração completa substitui os dados atuais do app. As chaves de API do analisador personalizado ficam no armazenamento seguro e não são gravadas nos arquivos de backup.';

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
      'Backup completo do app restaurado. As chaves de API do analisador precisam ser inseridas novamente.';

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
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Repositório no GitHub';

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
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. Custom timetable parser settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

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
  String get schoolSitesImportPreviewTitle => 'Review school-site import';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount valid sites, $invalidCount invalid entries.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'The file contains an empty school-site list.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Entry $position is invalid and will be skipped.';
  }

  @override
  String get schoolSitesImportMerge => 'Merge';

  @override
  String get schoolSitesImportReplace => 'Replace';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Replace current school sites?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'This removes $currentCount current sites and saves $importedCount imported sites. This cannot be undone.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'School-site data needs recovery';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked could not read the school-site file or its backup. Protected copies were created before writes were blocked.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'School-site storage is unavailable';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked cannot access school-site storage right now. Retry after checking storage access or device availability. Current site data will not be overwritten.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Recovery files or affected storage locations are listed below. Keep any files unchanged until the site list is recovered.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Start with no school sites';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Start with an empty school-site list?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Protected copies will be kept, but Sked will create a new empty school-site file. Continue only if you do not want to retry recovery first.';

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
  String get schoolWebImportOpenPageHint =>
      'Entre no site da escola dentro do app e depois navegue manualmente até a página do horário.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

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
  String get schoolWebImportGoBack => 'Página anterior';

  @override
  String get schoolWebImportLoadingPage => 'Carregando página…';

  @override
  String get schoolWebImportParsing => 'Analisando a página atual…';

  @override
  String get schoolWebImportLoadFailed =>
      'Falha ao carregar a página. Atualize ou tente novamente mais tarde.';

  @override
  String get schoolWebImportLoadTimedOut =>
      'O carregamento da página expirou. Atualize e tente novamente.';

  @override
  String get schoolWebImportUnknownOrigin => 'Site desconhecido';

  @override
  String get schoolWebImportCrossOriginTitle => 'Continuar para outro site?';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return 'O início de sessão na escola pode exigir a abertura de outro site. Continue apenas se confiar neste destino durante a sessão de importação atual:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage =>
      'O conteúdo da página atual está vazio e ainda não pode ser importado.';

  @override
  String get schoolWebImportSuccess => 'Horário web importado';

  @override
  String get schoolImportParserSettingsTitle =>
      'Configurações do analisador de horários';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure your own OpenAI-compatible endpoint. HTTP and HTTPS base URLs are supported.';

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
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

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
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

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
      'Gerencie calendários, eventos, lembretes e dados JSON / ICS.';

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
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'Hoje';

  @override
  String get addEvent => 'Add event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get eventTitle => 'Title';

  @override
  String get eventTitleRequired => 'Title is required';

  @override
  String get eventStartTime => 'Start time';

  @override
  String get eventEndTime => 'End time';

  @override
  String get eventDate => 'Date';

  @override
  String get eventTime => 'Time';

  @override
  String get eventNotes => 'Notes';

  @override
  String get eventColor => 'Color';

  @override
  String get eventRecurrence => 'Repeat';

  @override
  String get recurrenceNone => 'Does not repeat';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceEndDate => 'End date';

  @override
  String get recurrenceNoEndDate => 'No end date';

  @override
  String get recurrenceSetEndDate => 'Set';

  @override
  String get recurrenceChangeEndDate => 'Change';

  @override
  String get repeatsWeekly => 'Repeats weekly';

  @override
  String recurrenceUntil(Object date) {
    return 'Until $date';
  }

  @override
  String get switchToGeneralSchedule => 'Switch to General schedule';

  @override
  String get generalDisplaySettings => 'General display settings';

  @override
  String get generalDisplaySettingsDesc =>
      'Visualizações, barra de ferramentas, formato de data e adição rápida';

  @override
  String get closePopupOnOutsideTap => 'Close popup on tap outside';

  @override
  String get showGridLines => 'Show grid lines';

  @override
  String get generalScheduleImportExport => 'Schedule import & export';

  @override
  String get generalScheduleImportExportDesc =>
      'Import or share general schedules';

  @override
  String get importGeneralSchedules => 'Import schedules';

  @override
  String get importGeneralSchedulesDesc => 'Read schedules from a JSON file';

  @override
  String get shareGeneralSchedules => 'Share schedules';

  @override
  String get shareGeneralSchedulesDesc => 'Share schedules as a JSON file';

  @override
  String get saveGeneralSchedules => 'Save schedules';

  @override
  String get saveGeneralSchedulesDesc => 'Save schedules as a JSON file';

  @override
  String get selectSchedulesToExport => 'Select schedules to export';

  @override
  String get selectSchedulesToImport => 'Select schedules to import';

  @override
  String generalScheduleEventCount(int count) {
    return 'Events: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Imported $count schedules';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Replace current schedule with the imported one?';

  @override
  String get addAsNewSchedule => 'Add as new';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Please select at least one schedule.';

  @override
  String get noExportableScheduleMessage => 'No schedule available to export.';

  @override
  String get noSchedulesInImportMessage => 'Import file contains no schedules.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Choose exactly one schedule to replace the current one.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'No current schedule to replace.';

  @override
  String get calendars => 'Calendars';

  @override
  String get calendar => 'Calendar';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewDay => 'Dia';

  @override
  String get viewList => 'List';

  @override
  String get viewMonth => 'Month';

  @override
  String get eventDuplicated => 'Event duplicated';

  @override
  String get searchEvents => 'Search events';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filterByColor => 'Filter by color';

  @override
  String get allColors => 'All colors';

  @override
  String upcomingEventsCount(int count) {
    return 'Upcoming $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Overdue $count';
  }

  @override
  String get allDay => 'All-day';

  @override
  String moreEvents(int count) {
    return '+$count more';
  }

  @override
  String get noMatchingEvents => 'No matching events';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get addCalendar => 'Add calendar';

  @override
  String get newCalendar => 'New calendar';

  @override
  String get hideCalendar => 'Hide calendar';

  @override
  String get showCalendar => 'Show calendar';

  @override
  String get rename => 'Rename';

  @override
  String get renameCalendar => 'Rename calendar';

  @override
  String get name => 'Name';

  @override
  String get deleteCalendar => 'Delete calendar';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteThisOccurrence => 'Delete this';

  @override
  String get deleteFutureOccurrences => 'Delete future';

  @override
  String get deleteAllOccurrences => 'Delete all';

  @override
  String get duplicateEvent => 'Duplicate';

  @override
  String get repeatsDaily => 'Repeats daily';

  @override
  String get repeatsMonthly => 'Repeats monthly';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Repeats every $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count times';
  }

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceCustom => 'Custom';

  @override
  String get recurrenceEvery => 'Every';

  @override
  String get recurrenceUnit => 'Unit';

  @override
  String get recurrenceDays => 'Days';

  @override
  String get recurrenceWeeks => 'Weeks';

  @override
  String get recurrenceMonths => 'Months';

  @override
  String get recurrenceRepeatCount => 'Repeat count';

  @override
  String get recurrenceNoLimit => 'No limit';

  @override
  String get recurrencePositiveNumber => 'Enter a positive number';

  @override
  String get clearEndDate => 'Clear end date';

  @override
  String get pickDate => 'Pick date';

  @override
  String get pickTime => 'Pick time';

  @override
  String get reminder => 'In-app reminder';

  @override
  String get reminderAtStart => 'At start';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get reminderHourBefore => '1 hour before';

  @override
  String get reminderDayBefore => '1 day before';

  @override
  String get markReminderHandled => 'Mark handled';

  @override
  String get restoreReminder => 'Restore in-app reminder';

  @override
  String get reminderHandled => 'In-app reminder marked handled';

  @override
  String get reminderRestored => 'In-app reminder restored';

  @override
  String get reminderUpcoming => 'Upcoming';

  @override
  String get reminderOverdue => 'Overdue';

  @override
  String get showWeekends => 'Show weekends';

  @override
  String get startHour => 'Start hour';

  @override
  String get endHour => 'End hour';

  @override
  String get timeGridDensity => 'Time grid density';

  @override
  String get importJsonFile => 'Import JSON file';

  @override
  String get pasteJson => 'Paste JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Import calendars from copied JSON';

  @override
  String get importIcsFile => 'Import ICS file';

  @override
  String get importIcsFileDesc => 'Read events from an .ics calendar file';

  @override
  String get pasteIcs => 'Paste ICS';

  @override
  String get pasteIcsDesc => 'Import events from copied calendar text';

  @override
  String get copyJson => 'Copy JSON';

  @override
  String get copyJsonDesc => 'Copy selected calendars as JSON text';

  @override
  String get shareIcs => 'Share ICS';

  @override
  String get shareIcsDesc => 'Share selected calendars as .ics';

  @override
  String get saveIcs => 'Save ICS';

  @override
  String get saveIcsDesc => 'Save selected calendars as .ics';

  @override
  String get copyIcs => 'Copy ICS';

  @override
  String get copyIcsDesc => 'Copy selected calendars as ICS text';

  @override
  String get importIcs => 'Import ICS';

  @override
  String get icsContent => 'ICS content';

  @override
  String get pasteIcsContentHint => 'Paste BEGIN:VCALENDAR content here';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Found $count events. Import as a new calendar or replace the active calendar?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Imported $count schedules with $warningCount warnings';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Skipped an event without a start time.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Skipped an event with an unsupported start time.';

  @override
  String get importWarningAdjustedEnd =>
      'Adjusted an event whose end time was not after its start.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Unsupported ICS fields were added to notes: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Ignored unsupported repeat frequency: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'Select calendars to copy as ICS';

  @override
  String get selectCalendarsToExportIcs => 'Select calendars to export as ICS';

  @override
  String get exportIcsText => 'Export ICS text';

  @override
  String get exportJsonText => 'Export JSON text';

  @override
  String get dataRestoredFromBackupNotice =>
      'App data was restored from the previous backup because the main file failed to load.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Both the main data file and its backup are damaged. The app is now using a fresh state.';

  @override
  String get dataRecoveryCorruptTitle => 'Your data needs recovery';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked could not read the main data file or its backup. Protected copies were created before writes were blocked.';

  @override
  String get dataRecoveryIoFailureTitle => 'Storage is unavailable';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked cannot access local storage right now. Retry after checking storage access or device availability. Existing data will not be overwritten.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Update Sked to open this data';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'This data was created by a newer version of Sked. Update the app before trying again. Starting fresh is disabled to protect it.';

  @override
  String get dataRecoveryRetryAction => 'Retry';

  @override
  String get dataRecoveryArtifactsHint =>
      'Recovery files or affected storage locations are listed below. Keep any files unchanged until your data is recovered.';

  @override
  String get dataRecoveryArtifactsAction => 'Show recovery files and locations';

  @override
  String get dataRecoveryStartFreshAction => 'Start with new data';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Start with new data?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Protected copies will be kept, but Sked will create a new local data file. Continue only if you do not want to retry recovery first.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'In progress';

  @override
  String get deleteCourseTitle => 'Delete course';

  @override
  String get deleteCourseMessage => 'Delete this course?';

  @override
  String get showLunarCalendar => 'Show lunar calendar';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count events';
  }

  @override
  String get defaultView => 'Default view';

  @override
  String get generalDefaultViewSection => 'Startup';

  @override
  String get generalViewSwitchBehavior => 'View switch button';

  @override
  String get settingsWorkspaceMode => 'Active workspace';

  @override
  String get hideHomeWorkspaceNavigation => 'Hide workspace navigation';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Hides the bottom bar, navigation rail, or sidebar. Switch workspaces from Settings.';

  @override
  String get generalDateLabelFormat => 'Date label format';

  @override
  String get generalDateLabelFormatLocalized => 'Localized (2026 Jul)';

  @override
  String get generalDateLabelFormatSlash => 'Slash (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Toolbar layout';

  @override
  String get generalToolbarWidthPolicy => 'Toolbar space allocation';

  @override
  String get generalToolbarWidthContent => 'Automatic allocation';

  @override
  String get generalToolbarWidthBalanced => 'Balanced';

  @override
  String get generalToolbarWidthCalendarPriority => 'Calendar priority';

  @override
  String get generalToolbarWidthDatePriority => 'Date priority';

  @override
  String get generalViewSwitchCycle => 'Cycle through views';

  @override
  String get generalViewSwitchMenu => 'Open view menu';

  @override
  String get generalViewSwitchTooltip => 'Switch view';

  @override
  String get generalViewSwitchMenuTooltip => 'Choose view';

  @override
  String get generalViewLongPressTodayHint => 'Long-press to go to today';

  @override
  String get generalScheduleDisplaySection => 'Schedule display';

  @override
  String get generalTimeGridSection => 'Time grid';

  @override
  String get generalPopupSection => 'Popup behavior';

  @override
  String get quickActionsSection => 'Quick actions';

  @override
  String get showAddCourseFab => 'Show floating add course button';

  @override
  String get showAddCourseFabHint =>
      'Show or hide the floating add course button in the bottom-right corner of the timetable.';

  @override
  String get showAddEventFab => 'Show floating add event button';

  @override
  String get showAddEventFabHint =>
      'Show or hide the floating add event button in the bottom-right corner of the schedule.';

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
}
