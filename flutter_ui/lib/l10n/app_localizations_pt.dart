// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get home => 'Início';

  @override
  String get terminal => 'Terminal';

  @override
  String files(String arg0) {
    return '$arg0 · Arquivos';
  }

  @override
  String get newHost => 'Novo host';

  @override
  String edit(String arg0) {
    return 'Editar $arg0';
  }

  @override
  String get disconnectAndCloseTab => 'Desconectar e fechar aba';

  @override
  String disconnectFromAndCloseThisTab(String arg0) {
    return 'Desconectar de $arg0 e fechar esta aba?';
  }

  @override
  String get disconnectAndClose => 'Desconectar e fechar';

  @override
  String get newTerminal => 'Novo terminal';

  @override
  String get fileTransfer => 'Transferência de arquivos';

  @override
  String get edit2 => 'Editar';

  @override
  String get removeFromFavorites => 'Remover dos favoritos';

  @override
  String get addToFavorites => 'Adicionar aos favoritos';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get portForwarding => 'Encaminhamento de portas';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get delete => 'Excluir';

  @override
  String get nameForDuplicateHost => 'Nome da cópia do host';

  @override
  String copy(String arg0) {
    return 'Cópia de $arg0';
  }

  @override
  String disconnectAllSessionsFor(String arg0) {
    return 'Desconectar todas as sessões de $arg0?';
  }

  @override
  String get searchHosts => 'Buscar hosts';

  @override
  String get searchHostsOrEnterSshAddressCtrlK =>
      'Buscar hosts ou inserir endereço SSH (Ctrl K)';

  @override
  String get addHost => 'Adicionar host';

  @override
  String get noHostsYet => 'Nenhum host ainda';

  @override
  String get openTerminals => 'Terminais abertos';

  @override
  String get openFiles => 'Arquivos abertos';

  @override
  String menu(String arg0) {
    return 'Menu de $arg0';
  }

  @override
  String get settings => 'Configurações';

  @override
  String get helpAndLogs => 'Ajuda e logs';

  @override
  String get hostListCtrlB => 'Lista de hosts (Ctrl B)';

  @override
  String closeTab(String arg0) {
    return 'Fechar aba de $arg0';
  }

  @override
  String get newTabCtrlShiftT => 'Nova aba (Ctrl Shift T)';

  @override
  String get terminalMenu => 'Menu do terminal';

  @override
  String get importSshKey => 'Importar chave SSH';

  @override
  String get openSessions => 'Sessões abertas';

  @override
  String session(String arg0) {
    return 'Sessão $arg0';
  }

  @override
  String get connected => 'Conectado';

  @override
  String get connecting => 'Conectando';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get open => 'Abrir';

  @override
  String get connect => 'Conectar';

  @override
  String get address => 'Endereço';

  @override
  String get authentication => 'Autenticação';

  @override
  String get tryAllAvailableKeys => 'Tentar todas as chaves disponíveis';

  @override
  String get useServerSettings => 'Usar configurações do servidor';

  @override
  String get terminalProfile => 'Perfil do terminal';

  @override
  String get appDefaultProfile => 'Perfil padrão do app';

  @override
  String get manage => 'Gerenciar';

  @override
  String get minimize => 'Minimizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get closeWindow => 'Fechar janela';

  @override
  String get host => 'Host';

  @override
  String get profile => 'Perfil';

  @override
  String get sharedLoginAccount => 'Conta de login compartilhada';

  @override
  String get sshKeys => 'Chaves SSH';

  @override
  String enter(String arg0) {
    return 'Digite $arg0.';
  }

  @override
  String get enterAWholeNumber => 'Digite um número inteiro.';

  @override
  String get checkThePortRange => 'Verifique o intervalo de portas.';

  @override
  String currentValue(String arg0) {
    return '$arg0 (valor atual)';
  }

  @override
  String get select => 'Selecionar';

  @override
  String get defaultValue => 'Padrão';

  @override
  String get dsaUnsupported => ' (DSA não suportado)';

  @override
  String get windowsDefaultKeysAndAddedKeys =>
      'Chaves padrão do Windows e chaves adicionadas';

  @override
  String get noKey => 'Não usar chave';

  @override
  String get passwordSaved => 'Senha (salva)';

  @override
  String get password => 'Senha';

  @override
  String get storedEncryptedOnThisDeviceEnterItAgainAfter =>
      'Armazenada com criptografia neste dispositivo. Digite novamente após restaurar em outro dispositivo.';

  @override
  String get storedEncryptedOnThisDevice =>
      'Armazenada com criptografia neste dispositivo.';

  @override
  String get deleteSavedPassword => 'Excluir senha salva';

  @override
  String get accountName => 'Nome da conta';

  @override
  String get username => 'Nome de usuário';

  @override
  String appliesToHosts(String arg0) {
    return 'Aplica-se a $arg0 hosts';
  }

  @override
  String get display => 'Tela';

  @override
  String get profileName => 'Nome do perfil';

  @override
  String get colorTheme => 'Tema de cores';

  @override
  String get terminalFont => 'Fonte do terminal';

  @override
  String get appDefault => 'Padrão do app';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get characterEncoding => 'Codificação de caracteres';

  @override
  String get deleteKey => 'Tecla de apagar';

  @override
  String get columnsAutomatic => 'Colunas · automático';

  @override
  String get rowsAutomatic => 'Linhas · automático';

  @override
  String get forwarding => 'Encaminhamento';

  @override
  String get forwardingName => 'Nome do encaminhamento';

  @override
  String get type => 'Tipo';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remoto';

  @override
  String get forwardConnectionsFromAServerPortToAnAddress =>
      'Encaminha conexões de uma porta do servidor para um endereço neste dispositivo.';

  @override
  String get forwardConnectionsFromADevicePortToAnAddress =>
      'Encaminha conexões de uma porta deste dispositivo para um endereço do lado do servidor.';

  @override
  String get openASocks5ProxyOnThisDevice =>
      'Abre um proxy SOCKS5 neste dispositivo.';

  @override
  String get socks4IsUnsupportedChangeTheTypeToSocks5To =>
      'SOCKS4 não é suportado. Altere o tipo para SOCKS5.';

  @override
  String get listenAddressOnServer => 'Endereço de escuta no servidor';

  @override
  String get listenAddressOnThisDevice =>
      'Endereço de escuta neste dispositivo';

  @override
  String get text127001AccessibleOnlyOnThisDevice =>
      '127.0.0.1 · acessível apenas neste dispositivo';

  @override
  String get port => 'Porta';

  @override
  String get destinationAddress => 'Endereço de destino';

  @override
  String get publicKey => 'Chave pública';

  @override
  String get copyFingerprint => 'Copiar impressão digital';

  @override
  String get copyPublicKey => 'Copiar chave pública';

  @override
  String get keySettings => 'Configurações da chave';

  @override
  String get keyName => 'Nome da chave';

  @override
  String get confirmBeforeUse => 'Confirmar antes de usar';

  @override
  String get askForPermissionBeforeAuthenticatingWithThisKey =>
      'Pede permissão antes de autenticar com esta chave';

  @override
  String get importedPrivateKey => 'Chave privada importada';

  @override
  String get androidKeystoreP256Key => 'Chave P-256 do Android Keystore';

  @override
  String get authenticateWithAnImportedPrivateKeyFile =>
      'Autentica com um arquivo de chave privada importado';

  @override
  String get thePrivateKeyCannotBeExportedFromThisDevice =>
      'A chave privada não pode ser exportada deste dispositivo';

  @override
  String get disabledLegacyPrivateKey => 'Chave privada legada desativada';

  @override
  String get replaceItWithANewAndroidKeystoreKeyBefore =>
      'Substitua por uma nova chave do Android Keystore antes de excluir.';

  @override
  String get connectionType => 'Tipo de conexão';

  @override
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0) {
    return 'Conexões $arg0 não são suportadas. Altere para SSH ou local.';
  }

  @override
  String get hostName => 'Nome do host';

  @override
  String get name => 'Nome';

  @override
  String get serverAddress => 'Endereço do servidor';

  @override
  String get pasteUserHostPortIntoTheAddressFieldTo =>
      'Cole user@host:port no campo de endereço para preencher os detalhes.';

  @override
  String get advanced => 'Avançado';

  @override
  String get ipAddress => 'Endereço IP';

  @override
  String get automatic => 'Automático';

  @override
  String get jumpHost => 'Host de salto';

  @override
  String get directConnection => 'Conexão direta';

  @override
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings =>
      'Este tipo de conexão não usa as configurações de autenticação SSH.';

  @override
  String get account => 'Conta';

  @override
  String get doNotUse => 'Não usar';

  @override
  String usingAccount(String arg0) {
    return 'Usando a conta $arg0';
  }

  @override
  String get loginKey => 'Chave de login';

  @override
  String get registerKeyOnThisServer => 'Registrar chave neste servidor';

  @override
  String get logInOnceWithAPasswordToInstallThe =>
      'Entre uma vez com senha para instalar a chave pública';

  @override
  String get hostColor => 'Cor do host';

  @override
  String get previewInTheHomeListTabsAndNotifications =>
      'Prévia na lista inicial, nas abas e nas notificações';

  @override
  String get customHostColor => 'Cor personalizada do host';

  @override
  String appDefault2(String arg0) {
    return 'Padrão do app · $arg0';
  }

  @override
  String get manageProfiles => 'Gerenciar perfis';

  @override
  String get keepConnectionAlive => 'Manter conexão ativa';

  @override
  String get reconnectAutomaticallyAfterAnIOError =>
      'Reconectar automaticamente após erro de E/S';

  @override
  String get closeWithoutAsking => 'Fechar sem perguntar';

  @override
  String get closeTheTabImmediatelyAfterExit =>
      'Fechar a aba imediatamente após exit';

  @override
  String get sshCompression => 'Compressão SSH';

  @override
  String get enableOnlyOnSlowConnections => 'Ative apenas em conexões lentas';

  @override
  String get openTerminal => 'Abrir terminal';

  @override
  String get whenOffOnlyPortForwardingIsEnabled =>
      'Quando desativado, permite apenas encaminhamento de portas';

  @override
  String get overrideForThisHost => 'Personalizar para este host';

  @override
  String get scrollback => 'Histórico de rolagem';

  @override
  String linesDefault(String arg0) {
    return 'Linhas · padrão $arg0';
  }

  @override
  String get useCtrlAltAsMeta => 'Usar Ctrl+Alt como Meta';

  @override
  String get displayAndProfile => 'Tela e perfil';

  @override
  String get session2 => 'Sessão';

  @override
  String get editHost => 'Editar host';

  @override
  String get localShell => 'Shell local';

  @override
  String get selectKey => 'Selecionar chave';

  @override
  String get connectionSettings => 'Configurações de conexão';

  @override
  String get trustedServerKeys => 'Chaves de servidor confiáveis';

  @override
  String get nameForDuplicate => 'Nome da cópia';

  @override
  String get couldNotSave => 'Não foi possível salvar';

  @override
  String get details => 'Detalhes';

  @override
  String get changedFields => 'Campos alterados';

  @override
  String get changePassword => 'Alterar senha';

  @override
  String get none => 'Nenhum';

  @override
  String get saving => 'Salvando';

  @override
  String changed(String arg0) {
    return 'Alterado: $arg0';
  }

  @override
  String andOthers(String arg0) {
    return '$arg0 e outros';
  }

  @override
  String items(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '$count item',
      zero: '0 itens',
    );
    return '$_temp0';
  }

  @override
  String get saved => 'Salvo';

  @override
  String get undo => 'Desfazer';

  @override
  String get save => 'Salvar';

  @override
  String get saveAndOpenNewTerminal => 'Salvar e abrir novo terminal';

  @override
  String get deleteHost => 'Excluir host';

  @override
  String get couldNotSaveChanges => 'Não foi possível salvar as alterações';

  @override
  String get add => 'Adicionar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get saving2 => 'Salvando…';

  @override
  String get apply => 'Aplicar';

  @override
  String get back => 'Voltar';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get appDefaultFont => 'Fonte padrão do app';

  @override
  String get newSshKey => 'Nova chave SSH';

  @override
  String get enterAName => 'Digite um nome.';

  @override
  String get createAP256PrivateKeyInAndroidKeystore =>
      'Cria uma chave privada P-256 no Android Keystore e exige biometria a cada assinatura. A chave privada não pode ser copiada, exportada nem incluída em backup.';

  @override
  String get couldNotCreateKey => 'Não foi possível criar a chave';

  @override
  String get createKey => 'Criar chave';

  @override
  String get search => 'Buscar';

  @override
  String get saving3 => 'Salvando';

  @override
  String changes(String arg0) {
    return '$arg0 alterações';
  }

  @override
  String enterAValueBetweenAnd(String arg0, String arg1) {
    return 'Digite um valor entre $arg0 e $arg1';
  }

  @override
  String decrease(String arg0) {
    return 'Diminuir $arg0';
  }

  @override
  String increase(String arg0) {
    return 'Aumentar $arg0';
  }

  @override
  String get discardChanges => 'Descartar alterações';

  @override
  String get unsavedChangesWillBeLost =>
      'As alterações não salvas serão perdidas.';

  @override
  String get keepEditing => 'Continuar editando';

  @override
  String get discard => 'Descartar';

  @override
  String get selectColor => 'Selecionar cor';

  @override
  String get brightness => 'Brilho';

  @override
  String get hexColor => 'Cor hexadecimal';

  @override
  String get enterASixDigitColor => 'Digite uma cor de seis dígitos';

  @override
  String get menu2 => 'Menu';

  @override
  String get defaultProfile => 'Perfil padrão';

  @override
  String get theSavedConnectionSettingsAreInvalid =>
      'As configurações de conexão salvas são inválidas.';

  @override
  String theSavedSettingsAreInvalid(String arg0) {
    return 'As configurações salvas de $arg0 são inválidas.';
  }

  @override
  String get theSavedColorThemeIsInvalid => 'O tema de cores salvo é inválido.';

  @override
  String get checkTheSshAddress => 'Verifique o endereço SSH.';

  @override
  String get useAnSshHost => 'Use um host SSH.';

  @override
  String get thisTerminalUsesUtf8 => 'Este terminal usa UTF-8.';

  @override
  String get colorThemeNotFound => 'Tema de cores não encontrado.';

  @override
  String get enterAThemeName => 'Digite um nome para o tema.';

  @override
  String get aThemeWithThisNameAlreadyExists =>
      'Já existe um tema com esse nome.';

  @override
  String get colorsMustBeThreeOrSixDigitHexValues =>
      'As cores devem ter três ou seis dígitos hexadecimais.';

  @override
  String get invalidColorThemeFileFormat =>
      'Formato de arquivo de tema inválido.';

  @override
  String get defaultColorIndicesMustBeBetween0And15 =>
      'Os índices de cor padrão devem estar entre 0 e 15.';

  @override
  String get ansiColorIndicesMustBeBetween0And15 =>
      'Os índices de cor ANSI devem estar entre 0 e 15.';

  @override
  String get invalidThemeDescriptionFormat =>
      'Formato da descrição do tema inválido.';

  @override
  String get duplicateTheDefaultThemeBeforeEditingIt =>
      'Duplique o tema padrão antes de editá-lo.';

  @override
  String get checkTheColorRole => 'Verifique a função da cor.';

  @override
  String get unsupportedThemeOperation => 'Operação de tema não suportada.';

  @override
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved =>
      'Só é possível salvar novas chaves de servidor confirmadas explicitamente.';

  @override
  String get onlyTemporaryTransferFilesCanBeProcessed =>
      'Só é possível processar arquivos temporários de transferência.';

  @override
  String get checkTheSshJumpHostConnection =>
      'Verifique a conexão com o host de salto SSH.';

  @override
  String get enterAServerAddress => 'Digite o endereço do servidor.';

  @override
  String get noHostToRestore => 'Nenhum host para restaurar.';

  @override
  String get thisProfileIsInUse => 'Este perfil está em uso.';

  @override
  String get unsupportedLink => 'Link não suportado.';

  @override
  String get keyFile => 'Arquivo de chave';

  @override
  String unsupportedOperation(String arg0) {
    return 'Operação não suportada: $arg0';
  }

  @override
  String get androidKeystoreKeyUnavailable =>
      'Chave do Android Keystore indisponível';

  @override
  String get legacyPrivateKeyDisabled => 'Chave privada legada · desativada';

  @override
  String get toggleKeyboard => 'Alternar teclado';

  @override
  String get endSession => 'Encerrar sessão';

  @override
  String disconnectFrom(String arg0) {
    return 'Desconectar de $arg0?';
  }

  @override
  String get end => 'Encerrar';

  @override
  String get couldNotCloseConnection => 'Não foi possível fechar a conexão';

  @override
  String get noOpenSessions => 'Nenhuma sessão aberta.';

  @override
  String disconnected2(String arg0) {
    return 'Desconectado$arg0';
  }

  @override
  String end2(String arg0) {
    return 'Encerrar $arg0';
  }

  @override
  String get newTab => 'Nova aba';

  @override
  String close(String arg0) {
    return 'Fechar $arg0';
  }

  @override
  String get image => 'Imagem';

  @override
  String get words => 'Palavras';

  @override
  String get firstConnectionToThisServer =>
      'Primeira conexão com este servidor';

  @override
  String get biometricAuthentication => 'Autenticação biométrica';

  @override
  String logInTo(String arg0) {
    return 'Entrar em $arg0';
  }

  @override
  String get server => 'Servidor';

  @override
  String get hidePassword => 'Ocultar senha';

  @override
  String get showPassword => 'Mostrar senha';

  @override
  String get saveOnThisDevice => 'Salvar neste dispositivo';

  @override
  String get checkThatThisFingerprintMatchesTheOneProvidedBy =>
      'Verifique se esta impressão digital corresponde à fornecida pelo administrador do servidor.';

  @override
  String get fingerprintFormat => 'Formato da impressão digital';

  @override
  String authenticateWithKey(String arg0) {
    return 'Autenticar com a chave $arg0.';
  }

  @override
  String get cancelConnection => 'Cancelar conexão';

  @override
  String get reject => 'Recusar';

  @override
  String get trustAndConnect => 'Confiar e conectar';

  @override
  String get logIn => 'Entrar';

  @override
  String get continueAction => 'Continuar';

  @override
  String waitingForLogin(String arg0) {
    return '$arg0 aguardando login';
  }

  @override
  String get continueLogin => 'Continuar login';

  @override
  String pasteLines(String arg0) {
    return 'Colar $arg0 linhas?';
  }

  @override
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0) {
    return 'Colar $arg0 linhas no terminal pode executar comandos imediatamente.';
  }

  @override
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution =>
      'Caracteres de controle podem acionar ações do terminal ou executar comandos.';

  @override
  String get pasteWithoutTrailingEnter => 'Colar sem Enter no final';

  @override
  String pasteLines2(String arg0) {
    return 'Colar $arg0 linhas';
  }

  @override
  String get editText => 'Editar texto';

  @override
  String get textToSend => 'Texto a enviar';

  @override
  String get send => 'Enviar';

  @override
  String get selectEntireLine => 'Selecionar linha inteira';

  @override
  String get selectVisibleScreen => 'Selecionar tela visível';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get blockSelection => 'Seleção em bloco';

  @override
  String get share => 'Compartilhar';

  @override
  String get paste => 'Colar';

  @override
  String get copy2 => 'Copiar';

  @override
  String get editAndSend => 'Editar e enviar';

  @override
  String get moreSelectionOptions => 'Mais opções de seleção';

  @override
  String get selectionEnd => 'Fim da seleção';

  @override
  String get selectionStart => 'Início da seleção';

  @override
  String get clearSelection => 'Limpar seleção';

  @override
  String couldNotConnectTo(String arg0) {
    return 'Não foi possível conectar a $arg0';
  }

  @override
  String get couldNotCompleteOperation =>
      'Não foi possível concluir a operação';

  @override
  String get couldNotFinishOperation => 'Não foi possível concluir a operação';

  @override
  String checked(String arg0) {
    return 'Verificado · $arg0';
  }

  @override
  String occurred(String arg0) {
    return 'Ocorrido · $arg0';
  }

  @override
  String get copyErrorLog => 'Copiar log de erro';

  @override
  String get close2 => 'Fechar';

  @override
  String get saveElsewhere => 'Salvar em outro local';

  @override
  String get retry => 'Tentar novamente';

  @override
  String deletedHost(String arg0) {
    return 'Host $arg0 excluído';
  }

  @override
  String get ok => 'OK';

  @override
  String linesEnterInsertsANewline(num count, String arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linhas',
      one: '$count linha',
      zero: '0 linhas',
    );
    return '$_temp0 · Enter insere uma nova linha$arg1';
  }

  @override
  String get ctrlEnterSends => ', Ctrl Enter envia';

  @override
  String unsupported(String arg0) {
    return ' · $arg0 não suportado';
  }

  @override
  String verifyServerKeyFor(String arg0) {
    return 'Verificar chave do servidor $arg0';
  }

  @override
  String get trustServerKey => 'Confiar na chave do servidor';

  @override
  String authenticateWithKey2(String arg0) {
    return 'Autenticar com a chave $arg0.';
  }

  @override
  String get disconnectAll => 'Desconectar tudo';

  @override
  String get disconnectAllSessions => 'Desconectar todas as sessões?';

  @override
  String get disconnectAll2 => 'Desconectar tudo';

  @override
  String get removeServerKey => 'Remover a chave do servidor?';

  @override
  String get theServerKeyWillBeVerifiedAgainOnThe =>
      'A chave do servidor será verificada novamente na próxima conexão.';

  @override
  String get deleteServerKey => 'Excluir chave do servidor';

  @override
  String sessions(String arg0) {
    return ' · Sessões $arg0';
  }

  @override
  String get fileTransferSftp => 'Transferência de arquivos (SFTP)';

  @override
  String get favorites => 'Favoritos';

  @override
  String get quickConnect => 'Conexão rápida';

  @override
  String get createSshKeyOnThisDevice => 'Criar chave SSH neste dispositivo';

  @override
  String get sort => 'Ordenar';

  @override
  String get byColor => 'Por cor';

  @override
  String get byName => 'Por nome';

  @override
  String get help => 'Ajuda';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get couldNotPrepareAppData =>
      'Não foi possível preparar os dados do app';

  @override
  String get preparingTilde => 'Preparando Tilde';

  @override
  String get errorDetails => 'Detalhes do erro';

  @override
  String get tildeHomeDirectory => 'Diretório inicial do Tilde';

  @override
  String get inProgress => 'Em andamento';

  @override
  String get newOutput => 'Nova saída';

  @override
  String get error => 'Erro';

  @override
  String get notConnected => 'Não conectado';

  @override
  String sessions2(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessões',
      one: '$count sessão',
      zero: '0 sessões',
    );
    return ' · $_temp0';
  }

  @override
  String get connectToYourFirstServer => 'Conecte-se ao seu primeiro servidor';

  @override
  String get saveAHostToConnectWithADoubleClick =>
      'Salve um host para conectar com um clique duplo na próxima vez.';

  @override
  String get saveAServerToConnectQuicklyNextTime =>
      'Salve um servidor para conectar rapidamente na próxima vez.';

  @override
  String get saveAddressUserAndAuthentication =>
      'Salvar endereço, usuário e autenticação';

  @override
  String get connectNow => 'Conectar agora';

  @override
  String get connectByAddress => 'Conectar por endereço';

  @override
  String get enterSshUserHostInTheSearchFieldAnd =>
      'Digite ssh user@host na busca e pressione Enter';

  @override
  String get privateKeyFileSuchAsIdEd25519 =>
      'Arquivo de chave privada, como id_ed25519';

  @override
  String connectingTo(String arg0, String arg1) {
    return 'Conectando a $arg0:$arg1';
  }

  @override
  String get negotiatingSshConnection => 'Negociando conexão SSH';

  @override
  String get verifyingServerKey => 'Verificando chave do servidor';

  @override
  String authenticating(String arg0) {
    return 'Autenticando $arg0';
  }

  @override
  String get authenticated => 'Autenticado';

  @override
  String get openingTerminalSession => 'Abrindo sessão do terminal';

  @override
  String get confirmSshKeyUse => 'Confirmar uso da chave SSH';

  @override
  String get sshPrivateKeyPassphrase => 'Frase secreta da chave privada SSH';

  @override
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd =>
      'Conexão bloqueada porque a chave do servidor mudou. Confira e remova manualmente a chave do servidor salva.';

  @override
  String get preparingSshLogin => 'Preparando login SSH';

  @override
  String get loggedInButCouldNotSaveThePasswordSave =>
      'Login realizado, mas não foi possível salvar a senha. Salve-a novamente no editor do host.';

  @override
  String sendTo(String arg0) {
    return 'Enviar para $arg0';
  }

  @override
  String get send2 => 'Enviar';

  @override
  String get terminalSize => 'Tamanho do terminal';

  @override
  String get columns => 'Colunas';

  @override
  String get rows => 'Linhas';

  @override
  String get fullScreen => 'Tela cheia';

  @override
  String get autoHideTitleBar => 'Ocultar barra de título automaticamente';

  @override
  String get terminalSizeColumnsRows => 'Tamanho do terminal · colunas×linhas';

  @override
  String get resize => 'Redimensionar';

  @override
  String get text8024LeaveBlankForAutomaticSizing =>
      '80×24 · deixe em branco para ajuste automático';

  @override
  String get enterColumnsRowsSuchAs8024 => 'Digite colunas×linhas, como 80×24.';

  @override
  String get terminalLinks => 'Links do terminal';

  @override
  String get noLinksOnScreen => 'Não há links na tela.';

  @override
  String get enterText => 'Inserir texto';

  @override
  String get links => 'Links';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get couldNotVerifyServerKey =>
      'Não foi possível verificar a chave do servidor';

  @override
  String get couldNotLogIn => 'Não foi possível entrar';

  @override
  String get couldNotOpenTerminal => 'Não foi possível abrir o terminal';

  @override
  String get couldNotConnectToServer => 'Não foi possível conectar ao servidor';

  @override
  String connectingTo2(String arg0) {
    return 'Conectando a $arg0';
  }

  @override
  String get checkTheSavedServerKeyAndTheFingerprintProvided =>
      'Confira a chave do servidor salva e a impressão digital fornecida pelo administrador do servidor.';

  @override
  String get checkYourUsernameAndCredentialsIfUsingAnSsh =>
      'Verifique o usuário e as credenciais. Se usar uma chave SSH, registre a chave pública no servidor.';

  @override
  String get checkTheServerAddressPortAndNetworkConnection =>
      'Verifique o endereço, a porta e a conexão de rede do servidor.';

  @override
  String get connectionLog => 'Log de conexão';

  @override
  String get deviceList => 'Lista de dispositivos';

  @override
  String get view => 'Visualizar';

  @override
  String get dismissBanner => 'Dispensar banner';

  @override
  String get connectionClosed => 'Conexão encerrada';

  @override
  String get theServerEndedTheSession => 'O servidor encerrou a sessão';

  @override
  String get connectionEndedAfterAuthenticationFailed =>
      'Conexão encerrada após falha na autenticação';

  @override
  String get connectionLost => 'Conexão perdida';

  @override
  String ended(String arg0) {
    return 'Encerrado · $arg0';
  }

  @override
  String get copyOutput => 'Copiar saída';

  @override
  String sshKey(String arg0) {
    return 'Chave SSH de $arg0';
  }

  @override
  String get couldNotPrepareRegistration =>
      'Não foi possível preparar o registro';

  @override
  String get keyToRegister => 'Chave a registrar';

  @override
  String get newBiometricKey => 'Nova chave biométrica';

  @override
  String get createNewSshKey => 'Criar nova chave SSH';

  @override
  String get registerSshKeyLogin => 'Registrar login por chave SSH';

  @override
  String keyRegistration(String arg0, String arg1) {
    return 'Registro da chave de $arg0$arg1';
  }

  @override
  String get anotherHost => 'outro host';

  @override
  String get isInProgress => ' em andamento';

  @override
  String get isComplete => ' concluído';

  @override
  String get registrationPreparationForThisHost =>
      'Preparar o registro da chave neste host';

  @override
  String get installThePublicKeyThenVerifyKeyLoginWith =>
      'Instale a chave pública e verifique o login por chave em uma conexão separada.';

  @override
  String get newKeyName => 'Nome da nova chave';

  @override
  String get progress => 'Progresso';

  @override
  String get installPublicKey => 'Instalar chave pública';

  @override
  String get verifyKeyLogin => 'Verificar login por chave';

  @override
  String get applyToHost => 'Aplicar ao host';

  @override
  String get theServerRejectedTheKey => 'O servidor recusou a chave';

  @override
  String get theServerRequiresAdditionalAuthentication =>
      'O servidor exige autenticação adicional';

  @override
  String get couldNotCompleteThisStep => 'Não foi possível concluir esta etapa';

  @override
  String get installedOnServer => 'Instalada no servidor';

  @override
  String get keyAlreadyInstalled => 'A chave já está instalada';

  @override
  String get keyLoginVerified => 'Login por chave verificado';

  @override
  String get theServerRejectedThisKey => 'O servidor recusou esta chave';

  @override
  String get registrationComplete => 'Registro concluído';

  @override
  String usingKey(String arg0) {
    return 'Usando a chave $arg0';
  }

  @override
  String get removeSavedPasswordForThisHost =>
      'Remover a senha salva deste host';

  @override
  String get registerAndVerify => 'Registrar e verificar';

  @override
  String get continueInBackground => 'Continuar em segundo plano';

  @override
  String get previewColorThemeFontAndMargins =>
      'Prévia do tema, da fonte e das margens';

  @override
  String get srcBuildSampleMd => '\nsrc  build  sample.md';

  @override
  String get specialKeyBarPreview => 'Prévia da barra de teclas especiais';

  @override
  String get fileTransferIsAvailableForSshHosts =>
      'A transferência de arquivos está disponível para hosts SSH.';

  @override
  String get registerAKeyFromAConnectedSshSession =>
      'Registre uma chave em uma sessão SSH conectada.';

  @override
  String get onlySshAndLocalConnectionsAreSupported =>
      'Somente conexões SSH e locais são suportadas.';

  @override
  String get theConnectionTypeChangedOpenANewSessionFrom =>
      'O tipo de conexão mudou. Abra uma nova sessão na tela inicial.';

  @override
  String get calculatingTimeRemaining => 'Calculando tempo restante';

  @override
  String minutesSecondsRemaining(String arg0, String arg1) {
    return 'Restam $arg0 min e $arg1 s';
  }

  @override
  String secondsRemaining(String arg0) {
    return 'Tempo restante: $arg0 s';
  }

  @override
  String cancelling(String arg0) {
    return '$arg0 · Cancelando…';
  }

  @override
  String get checkingSize => 'Verificando tamanho';

  @override
  String get calculatingSpeed => 'Calculando velocidade';

  @override
  String active(String arg0) {
    return 'Em andamento: $arg0';
  }

  @override
  String queued(String arg0) {
    return 'Na fila: $arg0';
  }

  @override
  String failed(String arg0) {
    return 'Falhas: $arg0';
  }

  @override
  String completed(String arg0) {
    return 'Concluídos: $arg0';
  }

  @override
  String cancelled(String arg0) {
    return 'Cancelados: $arg0';
  }

  @override
  String get noTransfers => 'Nenhuma transferência';

  @override
  String get queued2 => 'Na fila';

  @override
  String get paused => 'Pausado';

  @override
  String get completed2 => 'Concluído';

  @override
  String get failed2 => 'Falhou';

  @override
  String get cancelOperation => 'Cancelar operação';

  @override
  String get openFolder => 'Abrir pasta';

  @override
  String couldNotComplete(String arg0) {
    return 'Não foi possível concluir: $arg0';
  }

  @override
  String items2(String arg0, String arg1, String arg2) {
    return 'Itens: $arg0 / $arg1$arg2';
  }

  @override
  String transfer(String arg0) {
    return 'Transferência · $arg0';
  }

  @override
  String get transferQueue => 'Fila de transferências';

  @override
  String get clearCompleted => 'Limpar concluídos';

  @override
  String get collapseTransferQueue => 'Recolher fila de transferências';

  @override
  String get expandTransferQueue => 'Expandir fila de transferências';

  @override
  String get all => 'Todos';

  @override
  String get selectARegularFile => 'Selecione um arquivo comum.';

  @override
  String get aFileWithTheSameNameAlreadyExists =>
      'Já existe um arquivo com o mesmo nome.';

  @override
  String get theSourceFileSizeChangedDuringTransfer =>
      'O tamanho do arquivo de origem mudou durante a transferência.';

  @override
  String get aFileWithTheSameNameAppearedDuringTransfer =>
      'Um arquivo com o mesmo nome foi criado durante a transferência.';

  @override
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0) {
    return 'Não foi possível remover o arquivo temporário do upload. Verifique no servidor. $arg0';
  }

  @override
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0) {
    return 'Não foi possível verificar o arquivo temporário do upload. Confira no servidor. $arg0';
  }

  @override
  String get changePermissions => 'Alterar permissões';

  @override
  String get read => 'Leitura';

  @override
  String get write => 'Gravação';

  @override
  String get execute => 'Execução';

  @override
  String get owner => 'Proprietário';

  @override
  String get group => 'Grupo';

  @override
  String get other => 'Outros';

  @override
  String get octalPermissions => 'Permissões em octal';

  @override
  String get enterThreeOrFourDigitsFrom0To7 =>
      'Digite três ou quatro dígitos de 0 a 7.';

  @override
  String get changePermissions2 => 'Alterar permissões';

  @override
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0) {
    return 'Não foi possível abrir a pasta. Verifique o caminho e as permissões.\n$arg0';
  }

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get create => 'Criar';

  @override
  String get destinationFolder => 'Pasta de destino';

  @override
  String move(String arg0) {
    return 'Mover $arg0';
  }

  @override
  String moveItems(String arg0) {
    return 'Mover seleção ($arg0)';
  }

  @override
  String get parentFolder => 'Pasta superior';

  @override
  String get folderPath => 'Caminho da pasta';

  @override
  String get editPath => 'Editar caminho';

  @override
  String get moveHere => 'Mover para cá';

  @override
  String permanentlyDeleteItems(String arg0) {
    return 'Excluir a seleção permanentemente ($arg0)?';
  }

  @override
  String childItems(String arg0) {
    return 'Itens contidos: $arg0';
  }

  @override
  String get checkingContents => 'Verificando conteúdo…';

  @override
  String get couldNotInspectFolderContentsTryAgain =>
      'Não foi possível verificar o conteúdo da pasta. Tente novamente.';

  @override
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0) {
    return 'Exclui os itens e o conteúdo das pastas, totalizando $arg0. Esta ação não pode ser desfeita.';
  }

  @override
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone =>
      'Exclui diretamente, sem usar a lixeira. Esta ação não pode ser desfeita.';

  @override
  String get deletePermanently => 'Excluir permanentemente';

  @override
  String get unknownModificationDate => 'Data de modificação desconhecida';

  @override
  String get aFileWithTheSameNameExists =>
      'Já existe um arquivo com o mesmo nome';

  @override
  String transferringItems(String arg0, String arg1) {
    return 'Transferindo: $arg0 / $arg1';
  }

  @override
  String get chooseWhichFileToKeepForEachConflict =>
      'Escolha qual arquivo manter em cada conflito.';

  @override
  String get fileBeingUploaded => 'Arquivo sendo enviado';

  @override
  String get fileBeingDownloaded => 'Arquivo sendo baixado';

  @override
  String get existingFileOnServer => 'Arquivo existente no servidor';

  @override
  String get existingFileOnDevice => 'Arquivo existente no dispositivo';

  @override
  String get unknownSize => 'Tamanho desconhecido';

  @override
  String get keepTheExistingFileAndSkipCopyingThisFile =>
      'Mantém o arquivo existente e ignora a cópia deste arquivo.';

  @override
  String get keepBothAddTheFirstAvailableNumberStartingAt =>
      'Mantém ambos. Adiciona o primeiro número disponível, a partir de (1), antes da extensão do arquivo copiado.';

  @override
  String get overwriteTheExistingFileWithTheCopiedFileThis =>
      'Substitui o arquivo existente pelo arquivo copiado. Esta ação não pode ser desfeita.';

  @override
  String get cancelCopyingKeepTheExistingFile =>
      'Cancele esta tarefa de cópia, incluindo os arquivos restantes. Mantenha os arquivos existentes.';

  @override
  String applyToRemainingItems(String arg0) {
    return 'Aplicar ao restante ($arg0)';
  }

  @override
  String get cancelTransfer => 'Cancelar transferência';

  @override
  String get cancelCopy => 'Cancelar cópia';

  @override
  String get loggingInForFileTransfer => 'Entrando para transferir arquivos';

  @override
  String get couldNotLogInForFileTransfer =>
      'Não foi possível entrar para transferir arquivos.';

  @override
  String get previewSupportsFilesUpTo4MibDownloadThe =>
      'A prévia aceita arquivos de até 4 MiB. Baixe o arquivo para abri-lo.';

  @override
  String get saveFile => 'Salvar arquivo';

  @override
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks =>
      'O editor não pode substituir pastas nem links simbólicos.';

  @override
  String get serverFileChanged => 'Arquivo do servidor alterado';

  @override
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0) {
    return '$arg0\nO arquivo no servidor mudou após o início da edição. Deseja substituí-lo?';
  }

  @override
  String overwriteTheExistingFile(String arg0) {
    return '$arg0\nDeseja substituir o arquivo existente?';
  }

  @override
  String get overwrite => 'Substituir';

  @override
  String get couldNotReconnectToTheServerCheckAuthenticationIn =>
      'Não foi possível reconectar ao servidor. Confira a autenticação no navegador de arquivos.';

  @override
  String get saveACopyElsewhere => 'Salvar cópia em outro local';

  @override
  String get saveCopy => 'Salvar cópia';

  @override
  String get enterAnAbsolutePathIncludingTheFileName =>
      'Digite um caminho absoluto com o nome do arquivo.';

  @override
  String get enterAPathDifferentFromTheOriginal =>
      'Digite um caminho diferente do original.';

  @override
  String get newFile => 'Novo arquivo';

  @override
  String get anItemWithTheSameNameAlreadyExists =>
      'Já existe um item com o mesmo nome.';

  @override
  String get thisItemIsBeingTransferred => 'Este item está sendo transferido.';

  @override
  String get rename => 'Renomear';

  @override
  String get change => 'Alterar';

  @override
  String get creatingFolder => 'Criando pasta';

  @override
  String get folderCreated => 'Pasta criada.';

  @override
  String get deleting => 'Excluindo';

  @override
  String deletingItems(String arg0) {
    return 'Excluindo seleção ($arg0)';
  }

  @override
  String deletedItems(String arg0) {
    return 'Itens excluídos: $arg0.';
  }

  @override
  String itemsWereDeleted(String arg0) {
    return ' · Itens já excluídos: $arg0.';
  }

  @override
  String get changingPermissions => 'Alterando permissões';

  @override
  String get symbolicLinkPermissionsWillNotBeChanged =>
      'As permissões dos links simbólicos não serão alteradas.';

  @override
  String get permissionsChanged => 'Permissões alteradas.';

  @override
  String operationCancelled(String arg0) {
    return 'Operação cancelada.$arg0';
  }

  @override
  String couldNotCompleteOperation2(String arg0) {
    return 'Não foi possível concluir a operação.$arg0';
  }

  @override
  String itemsPasteInTheDestinationFolder(String arg0, String arg1) {
    return 'Itens: $arg0 · $arg1 · Cole na pasta de destino.';
  }

  @override
  String get cut => 'Recortar';

  @override
  String get noFilesToPaste => 'Nenhum arquivo para colar.';

  @override
  String get cannotMoveOrCopyToTheSameLocationOr =>
      'Não é possível mover ou copiar para o mesmo local nem para dentro da pasta de origem.';

  @override
  String get move2 => 'Mover';

  @override
  String get copyTemporaryDownloadAndUpload =>
      'Copiar (download temporário e upload)';

  @override
  String get upload => 'Enviar';

  @override
  String get download => 'Baixar';

  @override
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform =>
      'Esta plataforma não permite escolher uma pasta de destino.';

  @override
  String get connectionClosed2 => 'Conexão encerrada.';

  @override
  String get downloadToFileManager => 'Baixar para o gerenciador de arquivos';

  @override
  String get theTemporaryExportPathAlreadyExists =>
      'O caminho temporário de exportação já existe.';

  @override
  String get cancelTransfersAndClose => 'Cancelar transferências e fechar';

  @override
  String get cancelActiveTransfersAndQueuedOperationsInThisTab =>
      'Cancelar as transferências ativas e as operações na fila desta aba?';

  @override
  String get uploadFolder => 'Enviar pasta';

  @override
  String get connectionCancelled => 'Conexão cancelada';

  @override
  String get couldNotOpenFileList =>
      'Não foi possível abrir a lista de arquivos';

  @override
  String fileTransfer2(String arg0) {
    return '$arg0 · Transferência de arquivos';
  }

  @override
  String get fileList => 'Lista de arquivos';

  @override
  String get checkTheFolderPathAndPermissionsThenTryAgain =>
      'Verifique o caminho da pasta e as permissões e tente novamente.';

  @override
  String get bookmarkCurrentFolder => 'Adicionar pasta atual aos favoritos';

  @override
  String get recentLocations => 'Locais recentes';

  @override
  String selected(String arg0) {
    return 'Selecionados: $arg0';
  }

  @override
  String get forward => 'Avançar';

  @override
  String get remoteFolderPath => 'Caminho da pasta remota';

  @override
  String get bookmarksAndRecentLocations => 'Favoritos e locais recentes';

  @override
  String get refresh => 'Atualizar';

  @override
  String get findInCurrentFolder => 'Buscar na pasta atual';

  @override
  String get readOnly => 'Somente leitura';

  @override
  String get discardChanges2 => 'Descartar alterações';

  @override
  String discardUnsavedChanges(String arg0) {
    return '$arg0\nDescartar as alterações não salvas?';
  }

  @override
  String get doNotSave => 'Não salvar';

  @override
  String get editing => 'Editando';

  @override
  String get saveCopyKeepOriginalUnchanged =>
      'Salvar cópia · manter o original';

  @override
  String savedACopyTo(String arg0) {
    return 'Uma cópia foi salva em $arg0.';
  }

  @override
  String get saved2 => 'Salvo.';

  @override
  String get couldNotOpenFile => 'Não foi possível abrir o arquivo';

  @override
  String couldNotOpen(String arg0) {
    return 'Não foi possível abrir $arg0';
  }

  @override
  String get previewIsUnsupportedForThisFileType =>
      'Não há prévia para este tipo de arquivo.';

  @override
  String get couldNotSaveYourChangesHaveBeenKept =>
      'Não foi possível salvar. As alterações foram mantidas.';

  @override
  String couldNotSave2(String arg0) {
    return 'Não foi possível salvar $arg0';
  }

  @override
  String utf8LineBytes(String arg0, String arg1, String arg2) {
    return ' · UTF-8$arg0 · Linhas: $arg1 · $arg2 B';
  }

  @override
  String get unsupportedFileType => 'Tipo de arquivo não suportado.';

  @override
  String get unsupportedRemoteFileType =>
      'Tipo de arquivo remoto não suportado.';

  @override
  String get theTransferSourceChangedStartANewTransfer =>
      'A origem da transferência mudou. Inicie uma nova transferência.';

  @override
  String get anItemWithThisNameExistsAndIsNot =>
      'Existe um item com este nome que não é uma pasta.';

  @override
  String get cannotOverwriteAFolderWithAFile =>
      'Não é possível substituir uma pasta por um arquivo.';

  @override
  String get namesCannotContainPathSeparatorsOrBeOr =>
      'O nome não pode conter separadores de caminho nem ser “.” ou “..”.';

  @override
  String get aFileOrFolderWithTheSameNameAlready =>
      'Já existe um arquivo ou pasta com o mesmo nome.';

  @override
  String get cannotMoveAFolderIntoItselfOrItsDescendants =>
      'Não é possível mover uma pasta para dentro dela mesma nem de suas subpastas.';

  @override
  String get cannotDeleteTheRootFolder =>
      'Não é possível excluir a pasta raiz.';

  @override
  String get theServerDeniedAccessCheckTheDestinationPathPermissions =>
      'O servidor negou acesso. Verifique as permissões do caminho de destino.';

  @override
  String get theFileOrFolderNoLongerExists =>
      'O arquivo ou pasta não existe mais.';

  @override
  String get serverConnectionLost => 'A conexão com o servidor foi perdida.';

  @override
  String get theServerCouldNotCompleteTheOperation =>
      'O servidor não conseguiu concluir a operação.';

  @override
  String get theServerIsNotRespondingCheckTheAddressAnd =>
      'O servidor não está respondendo. Verifique o endereço e a rede.';

  @override
  String get theServerDidNotAuthenticateYouCheckYourUsername =>
      'O servidor não autenticou você. Verifique o usuário, a chave e a senha.';

  @override
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0) {
    return 'O servidor recusou a conexão$arg0. Verifique o SSH e as configurações de porta.';
  }

  @override
  String onPort(String arg0) {
    return ' na porta $arg0';
  }

  @override
  String get checkTheServerConnection =>
      'Não foi possível se comunicar com o servidor. Verifique sua conexão de rede.';

  @override
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport =>
      'Erro inesperado. Copie os detalhes abaixo e entre em contato com o suporte.';

  @override
  String get transferCancelled => 'Transferência cancelada.';

  @override
  String get invalidFileName => 'Nome de arquivo inválido.';

  @override
  String get theFileWasNotReceivedCompletely =>
      'O arquivo não foi recebido por completo.';

  @override
  String get size => 'Tamanho';

  @override
  String get modified => 'Modificado';

  @override
  String get permissions => 'Permissões';

  @override
  String get ownerUid => 'UID do proprietário';

  @override
  String get groupGid => 'GID do grupo';

  @override
  String get showHiddenFilesAndFolders => 'Mostrar arquivos e pastas ocultos';

  @override
  String get descending => 'Ordem decrescente';

  @override
  String get visibleColumns => 'Colunas visíveis';

  @override
  String get preview => 'Prévia';

  @override
  String get move3 => 'Mover…';

  @override
  String get copyPath => 'Copiar caminho';

  @override
  String get info => 'Informações';

  @override
  String get changePermissions3 => 'Alterar permissões…';

  @override
  String get fileInformation => 'Informações do arquivo';

  @override
  String get path => 'Caminho';

  @override
  String get type2 => 'Tipo';

  @override
  String get folder => 'Pasta';

  @override
  String get symbolicLink => 'Link simbólico';

  @override
  String get file => 'Arquivo';

  @override
  String get clearSearch => 'Limpar busca';

  @override
  String get location => 'Local';

  @override
  String selected2(String arg0, String arg1) {
    return 'Selecionados: $arg0 · $arg1';
  }

  @override
  String get parentFolderBackspace => 'Pasta superior (Backspace)';

  @override
  String get loading => 'Carregando…';

  @override
  String get noFilesToDisplay => 'Nenhum arquivo para exibir.';

  @override
  String get noMatchingFiles => 'Nenhum arquivo correspondente.';

  @override
  String get applyNewName => 'Aplicar novo nome';

  @override
  String actions(String arg0) {
    return 'Ações de $arg0';
  }

  @override
  String items3(String arg0, String arg1) {
    return 'Itens: $arg0$arg1';
  }

  @override
  String hiddenFiltered(String arg0) {
    return ' · Ocultos/filtrados: $arg0';
  }

  @override
  String copy3(String arg0) {
    return 'Cópia de $arg0';
  }

  @override
  String hostsWillUseTheAppDefaultProfile(String arg0) {
    return 'Hosts que passarão a usar o perfil padrão do app: $arg0.';
  }

  @override
  String get deleteThisProfile => 'Excluir este perfil.';

  @override
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0) {
    return 'As conexões dos hosts serão mantidas ($arg0 no total), mas a senha compartilhada será excluída.';
  }

  @override
  String delete2(String arg0) {
    return 'Excluir $arg0';
  }

  @override
  String get setAsDefault => 'Definir como padrão';

  @override
  String add2(String arg0) {
    return 'Adicionar $arg0';
  }

  @override
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts =>
      'Compartilhe usuário, chave e senha entre vários hosts.';

  @override
  String get default2 => ' · Padrão';

  @override
  String get noHostsUsingThis => 'Nenhum host usa este item';

  @override
  String hosts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts',
      one: '$count host',
      zero: '0 hosts',
    );
    return '$_temp0';
  }

  @override
  String get privateKeyPassphrase => 'Frase secreta da chave privada';

  @override
  String get leaveBlankIfThereIsNoPassphrase =>
      'Deixe em branco se não houver frase secreta.';

  @override
  String get deleteKey2 => 'Excluir chave';

  @override
  String deleteKey3(String arg0) {
    return 'Excluir a chave $arg0?';
  }

  @override
  String get savePublicKeyFile => 'Salvar arquivo de chave pública';

  @override
  String get addKeyFile => 'Adicionar arquivo de chave';

  @override
  String get newKey => 'Nova chave';

  @override
  String get couldNotCompleteKeyOperation =>
      'Não foi possível concluir a operação da chave';

  @override
  String get importedPrivateKeysAreUsedFromProtectedAppStorage =>
      'As chaves privadas importadas são usadas no armazenamento protegido do app. As frases secretas salvas são protegidas pelo Keychain do iOS.';

  @override
  String get privateKeyFilesAreUsedFromTheirOriginalLocation =>
      'Os arquivos de chave privada são usados no local original. As frases secretas salvas são protegidas pela sua conta do Windows.';

  @override
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot =>
      'As chaves privadas são criadas no Android Keystore e não podem ser exportadas. As chaves legadas são mantidas desativadas.';

  @override
  String get disabled => 'Desativado';

  @override
  String options(String arg0) {
    return 'Opções de $arg0';
  }

  @override
  String get deleteForwarding => 'Excluir encaminhamento';

  @override
  String deleteSettingsFor(String arg0) {
    return 'Excluir as configurações de $arg0?';
  }

  @override
  String forwarding2(String arg0) {
    return '$arg0 · Encaminhamento';
  }

  @override
  String get addForwarding => 'Adicionar encaminhamento';

  @override
  String get sessionToControl => 'Sessão a controlar';

  @override
  String switchChangesApplyImmediately(String arg0) {
    return '$arg0 · Alterações no interruptor são aplicadas imediatamente';
  }

  @override
  String get defaultOnConnection => 'Padrão ao conectar';

  @override
  String get couldNotLoadForwarding =>
      'Não foi possível carregar o encaminhamento';

  @override
  String get socks4UnsupportedChangeToSocks5 =>
      'SOCKS4 não suportado · Altere para SOCKS5';

  @override
  String get removeServerKeyTrust => 'Remover confiança na chave do servidor';

  @override
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1) {
    return '$arg0:$arg1\nA chave do servidor será verificada na próxima conexão.';
  }

  @override
  String get noTrustedServerKeys => 'Nenhuma chave de servidor confiável.';

  @override
  String get use => 'Usar';

  @override
  String get editPalette => 'Editar paleta';

  @override
  String get export => 'Exportar';

  @override
  String get defaultTheme => 'Tema padrão';

  @override
  String get customTheme => 'Tema personalizado';

  @override
  String get nameForDuplicateTheme => 'Nome da cópia do tema';

  @override
  String get themeName => 'Nome do tema';

  @override
  String get deleteTheme => 'Excluir tema';

  @override
  String deleteTheme2(String arg0) {
    return 'Excluir o tema $arg0?';
  }

  @override
  String get newThemeName => 'Nome do novo tema';

  @override
  String get newTheme => 'Novo tema';

  @override
  String get import => 'Importar';

  @override
  String get textColor => 'Cor do texto';

  @override
  String get backgroundColor => 'Cor de fundo';

  @override
  String get cursorAndAppAccent => 'Cursor e destaque do app';

  @override
  String get couldNotLoadColorTheme =>
      'Não foi possível carregar o tema de cores';

  @override
  String get makeACopyToEditTheColors => 'Crie uma cópia para editar as cores.';

  @override
  String get lsSrcBuildSampleMd => '~ \$ ls\nsrc  build  sample.md\n';

  @override
  String get defaultColors => 'Cores padrão';

  @override
  String get lowContrastAgainstBackground => 'Baixo contraste com o fundo';

  @override
  String get ansiPalette => 'Paleta ANSI';

  @override
  String ansiColor(String arg0) {
    return 'Cor ANSI $arg0';
  }

  @override
  String get findServer => 'Localizar servidor';

  @override
  String get verifyServerKey => 'Verificar chave do servidor';

  @override
  String seconds(String arg0) {
    return '$arg0 s';
  }

  @override
  String get couldNotOpenAdPrivacySettingsTryAgain =>
      'Não foi possível abrir as configurações de privacidade dos anúncios. Tente novamente.';

  @override
  String get ad => 'Anúncio';

  @override
  String get adPrivacySettings => 'Privacidade dos anúncios';

  @override
  String get googleFontsMonospace => 'Google Fonts · Monoespaçadas';

  @override
  String get searchSettings => 'Buscar configurações';

  @override
  String get keyboard => 'Teclado';

  @override
  String get gestures => 'Gestos';

  @override
  String get connectionsAndNotifications => 'Conexões e notificações';

  @override
  String get securityAndBackup => 'Segurança e backup';

  @override
  String get manageFonts => 'Gerenciar fontes';

  @override
  String get specialKeyBar => 'Barra de teclas especiais';

  @override
  String specialKeys(String arg0) {
    return 'Teclas especiais: $arg0';
  }

  @override
  String twoFingerHorizontalSwipe(String arg0) {
    return 'Deslizar na horizontal com dois dedos · $arg0';
  }

  @override
  String get tmuxWindows => 'Janelas do tmux';

  @override
  String get disabled2 => 'Desativado';

  @override
  String get defaultTerminal => 'Terminal padrão';

  @override
  String get notificationsAndBell => 'Notificações e campainha';

  @override
  String sshKeys2(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chaves SSH',
      one: '$count chave SSH',
      zero: '0 chaves SSH',
    );
    return '$_temp0';
  }

  @override
  String get helpAndLogs2 => 'Ajuda e logs';

  @override
  String get horizontalMargins => 'Margens horizontais';

  @override
  String get lines => 'linhas';

  @override
  String get appTheme => 'Tema do app';

  @override
  String get systemTheme => 'Tema do sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Escuro';

  @override
  String get font => 'Fonte';

  @override
  String get orientation => 'Orientação';

  @override
  String get alwaysRotate => 'Sempre girar';

  @override
  String get portrait => 'Retrato';

  @override
  String get landscape => 'Paisagem';

  @override
  String get hideStatusBar => 'Ocultar barra de status';

  @override
  String get specialKeyLayout => 'Layout das teclas especiais';

  @override
  String get showWhenKeyboardIsClosed => 'Mostrar com o teclado fechado';

  @override
  String get whenPressingCtrlOrAlt => 'Ao pressionar Ctrl ou Alt';

  @override
  String get once => 'Uma vez';

  @override
  String get sticky => 'Fixar';

  @override
  String get stickyAltOnly => 'Fixar só Alt';

  @override
  String get keyboardToggleButton => 'Botão de alternar teclado';

  @override
  String get twoFingerHorizontalSwipe2 =>
      'Deslizar na horizontal com dois dedos';

  @override
  String get doNothing => 'Não fazer nada';

  @override
  String get switchSessions => 'Alternar sessões';

  @override
  String get switchTmuxWindows => 'Alternar janelas do tmux';

  @override
  String get prefixKey => 'Tecla de prefixo';

  @override
  String get twoFingerVerticalSwipe => 'Deslizar na vertical com dois dedos';

  @override
  String get scroll => 'Rolar';

  @override
  String get volumeButtonsChangeFontSize =>
      'Botões de volume alteram o tamanho da fonte';

  @override
  String get specialKeyVibration => 'Vibração das teclas especiais';

  @override
  String get defaultTerminalProfile => 'Perfil padrão do terminal';

  @override
  String get manageTerminalProfiles => 'Gerenciar perfis de terminal';

  @override
  String itemCount(String arg0) {
    return '$arg0';
  }

  @override
  String get appearance => 'Aparência';

  @override
  String get terminalTypeTerm => 'Tipo de terminal (TERM)';

  @override
  String get addTerminalType => 'Adicionar tipo de terminal';

  @override
  String get terminalType => 'Tipo de terminal';

  @override
  String get keepScreenAwakeWhileConnected =>
      'Manter tela ligada enquanto conectado';

  @override
  String get theTerminalScreenWillStayAwake =>
      'A tela do terminal permanecerá ligada';

  @override
  String get preventWiFiSleep => 'Impedir suspensão do Wi-Fi';

  @override
  String get usesMoreBattery => 'Consome mais bateria';

  @override
  String get backgroundConnectionNotification =>
      'Notificação de conexão em segundo plano';

  @override
  String get pinnedWhileConnected => 'Fixa enquanto conectado';

  @override
  String get terminalBell => 'Campainha do terminal';

  @override
  String get whenTheBellRings => 'Quando a campainha tocar';

  @override
  String get ignore => 'Ignorar';

  @override
  String get sound => 'Som';

  @override
  String get vibration => 'Vibração';

  @override
  String get soundAndVibration => 'Som e vibração';

  @override
  String get volume => 'Volume';

  @override
  String get notifications => 'Notificações';

  @override
  String get notificationPermissionRequired =>
      'Permissão de notificações necessária';

  @override
  String get allow => 'Permitir';

  @override
  String get enableConnectionNotifications => 'Ativar notificações de conexão';

  @override
  String get allowBellAndDisconnectionNotifications =>
      'Permitir notificações de campainha e desconexão';

  @override
  String get bellInBackground => 'Campainha em segundo plano';

  @override
  String get onDisconnect => 'Ao desconectar';

  @override
  String get androidNotificationSettings =>
      'Configurações de notificações do Android';

  @override
  String get notificationsOff => 'Notificações desativadas';

  @override
  String get notificationsAllowed => 'Notificações permitidas';

  @override
  String get lock => 'Bloqueio';

  @override
  String get unlockWhenStartingTheApp => 'Exigir desbloqueio ao iniciar o app';

  @override
  String get setUpAScreenLockFirst => 'Configure primeiro um bloqueio de tela';

  @override
  String get fingerprintOrScreenLock => 'Impressão digital ou bloqueio de tela';

  @override
  String get keysAndServers => 'Chaves e servidores';

  @override
  String get configurationFile => 'Arquivo de configuração';

  @override
  String get exportHosts => 'Exportar hosts';

  @override
  String get importHosts => 'Importar hosts';

  @override
  String get selectDefaultFont => 'Selecionar fonte padrão';

  @override
  String fontSample(String arg0) {
    return '$arg0 Aa';
  }

  @override
  String get bundledWithApp => 'Incluída no app';

  @override
  String get monospaceFont => 'Fonte monoespaçada';

  @override
  String get deleteFont => 'Excluir fonte';

  @override
  String get deleteThisFontFile => 'Excluir este arquivo de fonte?';

  @override
  String get removeFont => 'Remover fonte';

  @override
  String get preparingFont => 'Preparando fonte';

  @override
  String get importFontFile => 'Importar arquivo de fonte';

  @override
  String get findOnGoogleFonts => 'Buscar no Google Fonts';

  @override
  String get onlyMonospaceFontsAreShown =>
      'Somente fontes monoespaçadas são exibidas';

  @override
  String settings2(String arg0) {
    return 'Configurações › $arg0';
  }

  @override
  String get couldNotSaveSettings => 'Não foi possível salvar as configurações';

  @override
  String get resetSpecialKeyBar => 'Redefinir a barra de teclas especiais?';

  @override
  String get restoreTheDefaultHeightKeyOrderAndVisibility =>
      'Restaura a altura, a ordem e a visibilidade padrão das teclas.';

  @override
  String get longPressToDragTapToHide =>
      'Segure para arrastar · Toque para ocultar';

  @override
  String get hiddenKeys => 'Teclas ocultas';

  @override
  String get tapAKeyToMoveItHere => 'Toque em uma tecla para movê-la para cá';

  @override
  String get combineF1F12IntoFn => 'Agrupar F1–F12 em Fn';

  @override
  String get height => 'Altura';

  @override
  String get small => 'Pequeno';

  @override
  String get large => 'Grande';

  @override
  String get default3 => 'Padrão';

  @override
  String get escAndCtrlStayOnTheLeftKeyboardFn =>
      'Esc e Ctrl ficam à esquerda; teclado, Fn e Tab ficam à direita.';

  @override
  String get flutterLibraryLicenses => 'Licenças das bibliotecas Flutter';

  @override
  String get tips => 'Dicas';

  @override
  String get licensesAndTerms => 'Licenças e termos';

  @override
  String get projectAndContact => 'Projeto e contato';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get diagnosticLogs => 'Logs de diagnóstico';

  @override
  String get searchLogs => 'Buscar nos logs';

  @override
  String get saveNativeCrashLog => 'Salvar log de falha nativa';

  @override
  String get warning => 'Aviso';

  @override
  String get couldNotLoadLogs => 'Não foi possível carregar os logs';

  @override
  String get onlyAndroidKeystoreSshKeysAreSupported =>
      'Somente chaves SSH do Android Keystore são suportadas';

  @override
  String get onlyP256AndroidKeystoreKeysAreSupported =>
      'Somente chaves P-256 do Android Keystore são suportadas';

  @override
  String get invalidEcdsaSignature => 'Assinatura ECDSA inválida';

  @override
  String get invalidEcdsaSignatureValues =>
      'Valores de assinatura ECDSA inválidos';

  @override
  String get invalidX509PublicKey => 'Chave pública X509 inválida';

  @override
  String get invalidPublicKeyBitString =>
      'Sequência de bits da chave pública inválida';

  @override
  String get invalidRsaPublicKey => 'Chave pública RSA inválida';

  @override
  String get invalidEcCurve => 'Curva EC inválida';

  @override
  String get invalidUncompressedEcPoint => 'Ponto EC não comprimido inválido';

  @override
  String get invalidEd25519PublicKey => 'Chave pública Ed25519 inválida';

  @override
  String unsupportedSshPublicKeyAlgorithm(String arg0) {
    return 'Algoritmo de chave pública SSH não suportado: $arg0';
  }

  @override
  String get unsupportedSshEcCurve => 'Curva EC SSH não suportada';

  @override
  String get invalidDerSequence => 'Sequência DER inválida';

  @override
  String get privateKeyExportIsNotSupported =>
      'A exportação da chave privada não é suportada';

  @override
  String get publicKeyIsUnavailable => 'Chave pública indisponível';

  @override
  String unsupportedTerminalKey(String arg0) {
    return 'Tecla de terminal não suportada: $arg0';
  }

  @override
  String get disconnectBeforeReconnecting => 'Desconecte antes de reconectar';

  @override
  String get localShellIsNotOpen => 'O shell local não está aberto';

  @override
  String get unknownModifier => 'Tecla modificadora desconhecida';

  @override
  String unsupportedLocalTerminalOperation(String arg0) {
    return 'Operação de terminal local não suportada: $arg0';
  }

  @override
  String get invalidSshPublicKeyLine => 'Linha de chave pública SSH inválida';

  @override
  String get serverDidNotConfirmPublicKeyRegistration =>
      'O servidor não confirmou o registro da chave pública.';

  @override
  String get logInToASavedSshHostBeforeRegistering =>
      'Entre em um host SSH salvo antes de registrar a chave.';

  @override
  String get theSelectedSshKeyNoLongerExists =>
      'A chave SSH selecionada não existe mais.';

  @override
  String get aUniqueBiometricKeyNameIsRequired =>
      'Digite um nome exclusivo para a chave biométrica.';

  @override
  String get theOriginalSshConnectionIsNoLongerAuthenticated =>
      'A conexão SSH original não está mais autenticada.';

  @override
  String get keyOnlyLoginWasNotCompletedTheServerMay =>
      'Não foi possível entrar usando apenas a chave. O servidor pode exigir autenticação adicional. As configurações de login não foram alteradas.';

  @override
  String get theSavedHostNoLongerExists => 'O host salvo não existe mais.';

  @override
  String get theHostAddressChangedDuringRegistrationItsLoginSettings =>
      'O endereço do host mudou durante o registro. As configurações de login não foram alteradas.';

  @override
  String get invalidPtyDimensions => 'Dimensões de PTY inválidas';

  @override
  String get sshTargetIsRequired => 'Informe o destino SSH';

  @override
  String get sshSessionWasClosed => 'A sessão SSH foi encerrada';

  @override
  String get sshSessionIsNotConnected => 'A sessão SSH não está conectada';

  @override
  String get sshSessionsCannotBeReused =>
      'As sessões SSH não podem ser reutilizadas';

  @override
  String get noAddressForRequestedIpVersion =>
      'Não há endereço para a versão IP solicitada';

  @override
  String get sshHopConnectionTimedOut =>
      'A conexão SSH pelo host de salto expirou';

  @override
  String get sshSessionHasNoShell => 'A sessão SSH não tem um shell';

  @override
  String get sshSessionRequestTimedOut => 'A solicitação da sessão SSH expirou';

  @override
  String get invalidForwardBindPort =>
      'Porta de escuta do encaminhamento inválida';

  @override
  String get invalidForwardDestination => 'Destino de encaminhamento inválido';

  @override
  String get remoteForwardingRequestTimedOut =>
      'A solicitação de encaminhamento remoto expirou';

  @override
  String get remoteForwardingWasRefused =>
      'O encaminhamento remoto foi recusado';

  @override
  String get forwardConnectionTimedOut => 'A conexão de encaminhamento expirou';

  @override
  String get remoteForwardDestinationTimedOut =>
      'A conexão com o destino do encaminhamento remoto expirou';

  @override
  String get remoteForwardingCancellationWasRefused =>
      'O cancelamento do encaminhamento remoto foi recusado';

  @override
  String get sshAuthenticationCancelled => 'Autenticação SSH cancelada';

  @override
  String get concurrentSshAuthenticationPrompt =>
      'Já há uma solicitação de autenticação SSH em andamento';

  @override
  String get sessionDisposed => 'Sessão encerrada';

  @override
  String get disconnectBeforeRefreshingSshConfiguration =>
      'Desconecte antes de atualizar a configuração SSH';

  @override
  String get couldNotUnlockTheSelectedKey =>
      'Não foi possível desbloquear a chave selecionada.';

  @override
  String get logInToThisServerBeforeRegisteringAKey =>
      'Entre neste servidor antes de registrar a chave.';

  @override
  String get sshShellIsNotOpen => 'O shell SSH não está aberto';

  @override
  String get sshIsNotConnected => 'SSH não está conectado';

  @override
  String get portForwardIsMissing =>
      'A configuração do encaminhamento está ausente';

  @override
  String get unsupportedSshForwardType =>
      'Tipo de encaminhamento SSH não suportado';

  @override
  String unsupportedAppSshOperation(String arg0) {
    return 'Operação SSH do app não suportada: $arg0';
  }

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get newPassword => 'Nova senha';

  @override
  String get timedOutReadingWindowsSshSettings =>
      'A leitura das configurações SSH do Windows expirou.';

  @override
  String couldNotReadWindowsSshSettings(String arg0) {
    return 'Não foi possível ler as configurações SSH do Windows. $arg0';
  }

  @override
  String get windowsUserProfilePathIsUnavailable =>
      'O caminho do perfil de usuário do Windows está indisponível.';

  @override
  String unsupportedSshKeyPathVariable(String arg0) {
    return 'Variável de caminho de chave SSH não suportada: $arg0';
  }

  @override
  String couldNotImportFiles(String arg0) {
    return 'Não foi possível importar os arquivos: $arg0';
  }

  @override
  String uploadTo(String arg0) {
    return 'Enviar para $arg0';
  }

  @override
  String get currentFolder => 'Pasta atual';

  @override
  String get windowsUserDataFolderIsUnavailable =>
      'A pasta de dados do usuário do Windows está indisponível.';

  @override
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0) {
    return 'Não foi possível proteger as credenciais com a conta do Windows. $arg0';
  }

  @override
  String get altDrag => 'Arrastar com Alt';

  @override
  String get keyUp => 'Para cima';

  @override
  String get keyDown => 'Para baixo';

  @override
  String get keyHome => 'Início da linha';

  @override
  String get keyEnd => 'Fim da linha';

  @override
  String get keyPageUp => 'Página anterior';

  @override
  String get keyPageDown => 'Próxima página';

  @override
  String get keyInsert => 'Inserir';

  @override
  String get keyDelete => 'Excluir';

  @override
  String get skipCopy => 'Ignorar';

  @override
  String get keepBothFiles => 'Manter ambos';

  @override
  String get cancelJobNoApplyAll =>
      'A opção de aplicar aos arquivos restantes não está disponível ao cancelar a tarefa.';

  @override
  String get editAuthentication => 'Editar autenticação';

  @override
  String get serverMessage => 'Mensagem do servidor';

  @override
  String get cancellingOperation => 'Cancelando…';

  @override
  String get transferHeading => 'Transferências';

  @override
  String get newPasskey => 'New passkey';

  @override
  String get createPasskey => 'Create passkey';

  @override
  String get restorePasskey => 'Restore passkey connection';

  @override
  String get exportPasskey => 'Save passkey credential file';

  @override
  String get passkeyStorageNote =>
      'New SSH keys are encrypted using your passkey. Keep the encrypted credential backup and the passkey to restore after reinstalling or switching devices.';

  @override
  String get passkeyRestoreNote =>
      'Open the encrypted credential backup and authorize its passkey to restore. Historical connection files contain public metadata only.';

  @override
  String get passkeyUnavailable =>
      'Passkeys require Android 9 or later and a compatible credential provider.';

  @override
  String get passkeyCancelled => 'Passkey operation cancelled.';

  @override
  String get invalidPasskey => 'Invalid passkey response or connection file.';

  @override
  String get passkeyPrfTest => 'Passkey decryption test';

  @override
  String get passkeyPrfTestNote =>
      'Create a test passkey and save an encrypted test file. Open the file here, then in Tilde on another Android device using the same passkey. This test does not register an SSH key.';

  @override
  String get passkeyPrfCreate => 'Create test file';

  @override
  String get passkeyPrfOpen => 'Open test file';

  @override
  String get passkeyPrfSaved =>
      'Test file saved. Open it to check decryption on this device and another device.';

  @override
  String get passkeyPrfVerified =>
      'Decryption succeeded. This environment recovered the same passkey PRF value.';

  @override
  String get passkeyPrfUnsupported =>
      'The selected passkey provider does not support PRF in this environment.';

  @override
  String get passkeyPrfMismatch =>
      'Decryption failed. The file may be damaged or the PRF value may differ.';

  @override
  String get credentialKind => 'Credential type';

  @override
  String get passkeySshKeyMode => 'Create and protect an SSH key';

  @override
  String get passkeyPasswordMode => 'Protect an SSH password';

  @override
  String get passkeyPasswordNote =>
      'Unlocks only for the specified server and account. SSH encrypts transport, but the server receives the password. Keep the encrypted backup and the passkey.';

  @override
  String get passkeyPasswordSelectNote =>
      'Choose a passkey-protected credential above. Creating passwords with the previous device storage is disabled.';

  @override
  String get legacyCredential => 'Deprecated · migration recommended';

  @override
  String get credentialFieldRequired => 'This field is required.';

  @override
  String get credentialPortInvalid => 'Enter a valid SSH port.';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');
}
