// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get home => 'Inicio';

  @override
  String get terminal => 'Terminal';

  @override
  String files(String arg0) {
    return '$arg0 · Archivos';
  }

  @override
  String get newHost => 'Nuevo host';

  @override
  String edit(String arg0) {
    return 'Editar $arg0';
  }

  @override
  String get disconnectAndCloseTab => 'Desconectar y cerrar pestaña';

  @override
  String disconnectFromAndCloseThisTab(String arg0) {
    return '¿Desconectar de $arg0 y cerrar esta pestaña?';
  }

  @override
  String get disconnectAndClose => 'Desconectar y cerrar';

  @override
  String get newTerminal => 'Nuevo terminal';

  @override
  String get fileTransfer => 'Transferencia de archivos';

  @override
  String get edit2 => 'Editar';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get addToFavorites => 'Añadir a favoritos';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get portForwarding => 'Reenvío de puertos';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get delete => 'Eliminar';

  @override
  String get nameForDuplicateHost => 'Nombre de la copia del host';

  @override
  String copy(String arg0) {
    return 'Copia de $arg0';
  }

  @override
  String disconnectAllSessionsFor(String arg0) {
    return '¿Desconectar todas las sesiones de $arg0?';
  }

  @override
  String get searchHosts => 'Buscar hosts';

  @override
  String get searchHostsOrEnterSshAddressCtrlK =>
      'Buscar hosts o introducir dirección SSH (Ctrl K)';

  @override
  String get addHost => 'Añadir host';

  @override
  String get noHostsYet => 'Aún no hay hosts';

  @override
  String get openTerminals => 'Terminales abiertos';

  @override
  String get openFiles => 'Archivos abiertos';

  @override
  String menu(String arg0) {
    return 'Menú de $arg0';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get helpAndLogs => 'Ayuda y registros';

  @override
  String get hostListCtrlB => 'Lista de hosts (Ctrl B)';

  @override
  String closeTab(String arg0) {
    return 'Cerrar pestaña de $arg0';
  }

  @override
  String get newTabCtrlShiftT => 'Nueva pestaña (Ctrl Shift T)';

  @override
  String get terminalMenu => 'Menú del terminal';

  @override
  String get importSshKey => 'Importar clave SSH';

  @override
  String get openSessions => 'Sesiones abiertas';

  @override
  String session(String arg0) {
    return 'Sesión $arg0';
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
  String get address => 'Dirección';

  @override
  String get authentication => 'Autenticación';

  @override
  String get tryAllAvailableKeys => 'Probar todas las claves disponibles';

  @override
  String get useServerSettings => 'Usar ajustes del servidor';

  @override
  String get terminalProfile => 'Perfil del terminal';

  @override
  String get appDefaultProfile => 'Perfil predeterminado de la app';

  @override
  String get manage => 'Gestionar';

  @override
  String get minimize => 'Minimizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get closeWindow => 'Cerrar ventana';

  @override
  String get host => 'Host';

  @override
  String get profile => 'Perfil';

  @override
  String get sharedLoginAccount => 'Cuenta de acceso compartida';

  @override
  String get sshKeys => 'Claves SSH';

  @override
  String enter(String arg0) {
    return 'Introduce $arg0.';
  }

  @override
  String get enterAWholeNumber => 'Introduce un número entero.';

  @override
  String get checkThePortRange => 'Comprueba el intervalo de puertos.';

  @override
  String currentValue(String arg0) {
    return '$arg0 (valor actual)';
  }

  @override
  String get select => 'Seleccionar';

  @override
  String get defaultValue => 'Predeterminado';

  @override
  String get dsaUnsupported => ' (DSA no compatible)';

  @override
  String get windowsDefaultKeysAndAddedKeys =>
      'Claves predeterminadas de Windows y claves añadidas';

  @override
  String get noKey => 'No usar clave';

  @override
  String get passwordSaved => 'Contraseña (guardada)';

  @override
  String get password => 'Contraseña';

  @override
  String get storedEncryptedOnThisDeviceEnterItAgainAfter =>
      'Se guarda cifrada en este dispositivo. Vuelve a introducirla tras restaurar en otro dispositivo.';

  @override
  String get storedEncryptedOnThisDevice =>
      'Se guarda cifrada en este dispositivo.';

  @override
  String get deleteSavedPassword => 'Eliminar contraseña guardada';

  @override
  String get accountName => 'Nombre de la cuenta';

  @override
  String get username => 'Nombre de usuario';

  @override
  String appliesToHosts(String arg0) {
    return 'Se aplica a $arg0 hosts';
  }

  @override
  String get display => 'Pantalla';

  @override
  String get profileName => 'Nombre del perfil';

  @override
  String get colorTheme => 'Tema de colores';

  @override
  String get terminalFont => 'Fuente del terminal';

  @override
  String get appDefault => 'Valor predeterminado de la app';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get characterEncoding => 'Codificación de caracteres';

  @override
  String get deleteKey => 'Tecla de borrado';

  @override
  String get columnsAutomatic => 'Columnas · automático';

  @override
  String get rowsAutomatic => 'Filas · automático';

  @override
  String get forwarding => 'Reenvío';

  @override
  String get forwardingName => 'Nombre del reenvío';

  @override
  String get type => 'Tipo';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remoto';

  @override
  String get forwardConnectionsFromAServerPortToAnAddress =>
      'Reenvía conexiones de un puerto del servidor a una dirección de este dispositivo.';

  @override
  String get forwardConnectionsFromADevicePortToAnAddress =>
      'Reenvía conexiones de un puerto del dispositivo a una dirección del lado del servidor.';

  @override
  String get openASocks5ProxyOnThisDevice =>
      'Abre un proxy SOCKS5 en este dispositivo.';

  @override
  String get socks4IsUnsupportedChangeTheTypeToSocks5To =>
      'SOCKS4 no es compatible. Cambia el tipo a SOCKS5.';

  @override
  String get listenAddressOnServer => 'Dirección de escucha en el servidor';

  @override
  String get listenAddressOnThisDevice =>
      'Dirección de escucha en este dispositivo';

  @override
  String get text127001AccessibleOnlyOnThisDevice =>
      '127.0.0.1 · accesible solo desde este dispositivo';

  @override
  String get port => 'Puerto';

  @override
  String get destinationAddress => 'Dirección de destino';

  @override
  String get publicKey => 'Clave pública';

  @override
  String get copyFingerprint => 'Copiar huella digital';

  @override
  String get copyPublicKey => 'Copiar clave pública';

  @override
  String get keySettings => 'Ajustes de la clave';

  @override
  String get keyName => 'Nombre de la clave';

  @override
  String get confirmBeforeUse => 'Confirmar antes de usar';

  @override
  String get askForPermissionBeforeAuthenticatingWithThisKey =>
      'Pide permiso antes de autenticar con esta clave';

  @override
  String get importedPrivateKey => 'Clave privada importada';

  @override
  String get androidKeystoreP256Key => 'Clave P-256 de Android Keystore';

  @override
  String get authenticateWithAnImportedPrivateKeyFile =>
      'Autentica con un archivo de clave privada importado';

  @override
  String get thePrivateKeyCannotBeExportedFromThisDevice =>
      'La clave privada no se puede exportar de este dispositivo';

  @override
  String get disabledLegacyPrivateKey => 'Clave privada antigua desactivada';

  @override
  String get replaceItWithANewAndroidKeystoreKeyBefore =>
      'Sustitúyela por una nueva clave de Android Keystore antes de eliminarla.';

  @override
  String get connectionType => 'Tipo de conexión';

  @override
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0) {
    return 'Las conexiones $arg0 no son compatibles. Cambia a SSH o local.';
  }

  @override
  String get hostName => 'Nombre del host';

  @override
  String get name => 'Nombre';

  @override
  String get serverAddress => 'Dirección del servidor';

  @override
  String get pasteUserHostPortIntoTheAddressFieldTo =>
      'Pega user@host:port en el campo de dirección para rellenar los datos.';

  @override
  String get advanced => 'Avanzado';

  @override
  String get ipAddress => 'Dirección IP';

  @override
  String get automatic => 'Automático';

  @override
  String get jumpHost => 'Host de salto';

  @override
  String get directConnection => 'Conexión directa';

  @override
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings =>
      'Este tipo de conexión no usa los ajustes de autenticación SSH.';

  @override
  String get account => 'Cuenta';

  @override
  String get doNotUse => 'No usar';

  @override
  String usingAccount(String arg0) {
    return 'Usando la cuenta $arg0';
  }

  @override
  String get loginKey => 'Clave de inicio de sesión';

  @override
  String get registerKeyOnThisServer => 'Registrar clave en este servidor';

  @override
  String get logInOnceWithAPasswordToInstallThe =>
      'Inicia sesión una vez con contraseña para instalar la clave pública';

  @override
  String get hostColor => 'Color del host';

  @override
  String get previewInTheHomeListTabsAndNotifications =>
      'Vista previa en la lista de inicio, las pestañas y las notificaciones';

  @override
  String get customHostColor => 'Color personalizado del host';

  @override
  String appDefault2(String arg0) {
    return 'Valor predeterminado de la app · $arg0';
  }

  @override
  String get manageProfiles => 'Gestionar perfiles';

  @override
  String get keepConnectionAlive => 'Mantener conexión activa';

  @override
  String get reconnectAutomaticallyAfterAnIOError =>
      'Reconectar automáticamente tras un error de E/S';

  @override
  String get closeWithoutAsking => 'Cerrar sin preguntar';

  @override
  String get closeTheTabImmediatelyAfterExit =>
      'Cerrar la pestaña inmediatamente después de exit';

  @override
  String get sshCompression => 'Compresión SSH';

  @override
  String get enableOnlyOnSlowConnections =>
      'Actívalo solo en conexiones lentas';

  @override
  String get openTerminal => 'Abrir terminal';

  @override
  String get whenOffOnlyPortForwardingIsEnabled =>
      'Si se desactiva, solo se habilita el reenvío de puertos';

  @override
  String get overrideForThisHost => 'Personalizar para este host';

  @override
  String get scrollback => 'Historial de desplazamiento';

  @override
  String linesDefault(String arg0) {
    return 'Líneas · valor predeterminado $arg0';
  }

  @override
  String get useCtrlAltAsMeta => 'Usar Ctrl+Alt como Meta';

  @override
  String get displayAndProfile => 'Pantalla y perfil';

  @override
  String get session2 => 'Sesión';

  @override
  String get editHost => 'Editar host';

  @override
  String get localShell => 'Shell local';

  @override
  String get selectKey => 'Seleccionar clave';

  @override
  String get connectionSettings => 'Ajustes de conexión';

  @override
  String get trustedServerKeys => 'Claves de servidor de confianza';

  @override
  String get nameForDuplicate => 'Nombre de la copia';

  @override
  String get couldNotSave => 'No se pudo guardar';

  @override
  String get details => 'Detalles';

  @override
  String get changedFields => 'Campos modificados';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get none => 'Ninguno';

  @override
  String get saving => 'Guardando';

  @override
  String changed(String arg0) {
    return 'Se ha cambiado $arg0';
  }

  @override
  String andOthers(String arg0) {
    return '$arg0 y otros';
  }

  @override
  String items(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '$count elemento',
    );
    return '$_temp0';
  }

  @override
  String get saved => 'Guardado';

  @override
  String get undo => 'Deshacer';

  @override
  String get save => 'Guardar';

  @override
  String get saveAndOpenNewTerminal => 'Guardar y abrir nuevo terminal';

  @override
  String get deleteHost => 'Eliminar host';

  @override
  String get couldNotSaveChanges => 'No se pudieron guardar los cambios';

  @override
  String get add => 'Añadir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get saving2 => 'Guardando…';

  @override
  String get apply => 'Aplicar';

  @override
  String get back => 'Atrás';

  @override
  String get systemDefault => 'Valor predeterminado del sistema';

  @override
  String get appDefaultFont => 'Fuente predeterminada de la app';

  @override
  String get newSshKey => 'Nueva clave SSH';

  @override
  String get enterAName => 'Introduce un nombre.';

  @override
  String get createAP256PrivateKeyInAndroidKeystore =>
      'Crea una clave privada P-256 en Android Keystore y exige autenticación biométrica en cada firma. La clave privada no se puede copiar, exportar ni incluir en copias de seguridad.';

  @override
  String get couldNotCreateKey => 'No se pudo crear la clave';

  @override
  String get createKey => 'Crear clave';

  @override
  String get search => 'Buscar';

  @override
  String get saving3 => 'Guardando';

  @override
  String changes(String arg0) {
    return '$arg0 cambios';
  }

  @override
  String enterAValueBetweenAnd(String arg0, String arg1) {
    return 'Introduce un valor entre $arg0 y $arg1';
  }

  @override
  String decrease(String arg0) {
    return 'Reducir $arg0';
  }

  @override
  String increase(String arg0) {
    return 'Aumentar $arg0';
  }

  @override
  String get discardChanges => 'Descartar cambios';

  @override
  String get unsavedChangesWillBeLost => 'Se perderán los cambios sin guardar.';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get discard => 'Descartar';

  @override
  String get selectColor => 'Seleccionar color';

  @override
  String get brightness => 'Brillo';

  @override
  String get hexColor => 'Color hexadecimal';

  @override
  String get enterASixDigitColor => 'Introduce un color de seis dígitos';

  @override
  String get menu2 => 'Menú';

  @override
  String get defaultProfile => 'Perfil predeterminado';

  @override
  String get theSavedConnectionSettingsAreInvalid =>
      'Los ajustes de conexión guardados no son válidos.';

  @override
  String theSavedSettingsAreInvalid(String arg0) {
    return 'Los ajustes guardados de $arg0 no son válidos.';
  }

  @override
  String get theSavedColorThemeIsInvalid =>
      'El tema de colores guardado no es válido.';

  @override
  String get checkTheSshAddress => 'Comprueba la dirección SSH.';

  @override
  String get useAnSshHost => 'Usa un host SSH.';

  @override
  String get thisTerminalUsesUtf8 => 'Este terminal usa UTF-8.';

  @override
  String get colorThemeNotFound => 'No se ha encontrado el tema de colores.';

  @override
  String get enterAThemeName => 'Introduce un nombre para el tema.';

  @override
  String get aThemeWithThisNameAlreadyExists =>
      'Ya existe un tema con ese nombre.';

  @override
  String get colorsMustBeThreeOrSixDigitHexValues =>
      'Los colores deben tener tres o seis dígitos hexadecimales.';

  @override
  String get invalidColorThemeFileFormat =>
      'El formato del archivo de tema no es válido.';

  @override
  String get defaultColorIndicesMustBeBetween0And15 =>
      'Los índices de color predeterminados deben estar entre 0 y 15.';

  @override
  String get ansiColorIndicesMustBeBetween0And15 =>
      'Los índices de color ANSI deben estar entre 0 y 15.';

  @override
  String get invalidThemeDescriptionFormat =>
      'El formato de la descripción del tema no es válido.';

  @override
  String get duplicateTheDefaultThemeBeforeEditingIt =>
      'Duplica el tema predeterminado antes de editarlo.';

  @override
  String get checkTheColorRole => 'Comprueba la función del color.';

  @override
  String get unsupportedThemeOperation => 'Operación de tema no compatible.';

  @override
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved =>
      'Solo se pueden guardar claves nuevas del servidor confirmadas expresamente.';

  @override
  String get onlyTemporaryTransferFilesCanBeProcessed =>
      'Solo se pueden procesar archivos temporales de transferencia.';

  @override
  String get checkTheSshJumpHostConnection =>
      'Comprueba la conexión con el host de salto SSH.';

  @override
  String get enterAServerAddress => 'Introduce la dirección del servidor.';

  @override
  String get noHostToRestore => 'No hay ningún host que restaurar.';

  @override
  String get thisProfileIsInUse => 'Este perfil está en uso.';

  @override
  String get unsupportedLink => 'Enlace no compatible.';

  @override
  String get keyFile => 'Archivo de clave';

  @override
  String unsupportedOperation(String arg0) {
    return 'Operación no compatible: $arg0';
  }

  @override
  String get androidKeystoreKeyUnavailable =>
      'Clave de Android Keystore no disponible';

  @override
  String get legacyPrivateKeyDisabled => 'Clave privada antigua · desactivada';

  @override
  String get toggleKeyboard => 'Alternar teclado';

  @override
  String get endSession => 'Finalizar sesión';

  @override
  String disconnectFrom(String arg0) {
    return '¿Desconectar de $arg0?';
  }

  @override
  String get end => 'Finalizar';

  @override
  String get couldNotCloseConnection => 'No se pudo cerrar la conexión';

  @override
  String get noOpenSessions => 'No hay sesiones abiertas.';

  @override
  String disconnected2(String arg0) {
    return 'Desconectado$arg0';
  }

  @override
  String end2(String arg0) {
    return 'Finalizar $arg0';
  }

  @override
  String get newTab => 'Nueva pestaña';

  @override
  String close(String arg0) {
    return 'Cerrar $arg0';
  }

  @override
  String get image => 'Imagen';

  @override
  String get words => 'Palabras';

  @override
  String get firstConnectionToThisServer =>
      'Primera conexión con este servidor';

  @override
  String get biometricAuthentication => 'Autenticación biométrica';

  @override
  String logInTo(String arg0) {
    return 'Iniciar sesión en $arg0';
  }

  @override
  String get server => 'Servidor';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get saveOnThisDevice => 'Guardar en este dispositivo';

  @override
  String get checkThatThisFingerprintMatchesTheOneProvidedBy =>
      'Comprueba que esta huella digital coincide con la proporcionada por el administrador del servidor.';

  @override
  String get fingerprintFormat => 'Formato de huella digital';

  @override
  String authenticateWithKey(String arg0) {
    return 'Autenticar con la clave $arg0.';
  }

  @override
  String get cancelConnection => 'Cancelar conexión';

  @override
  String get reject => 'Rechazar';

  @override
  String get trustAndConnect => 'Confiar y conectar';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get continueAction => 'Continuar';

  @override
  String waitingForLogin(String arg0) {
    return '$arg0 en espera de inicio de sesión';
  }

  @override
  String get continueLogin => 'Continuar inicio de sesión';

  @override
  String pasteLines(String arg0) {
    return '¿Pegar $arg0 líneas?';
  }

  @override
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0) {
    return 'Pegar $arg0 líneas en el terminal puede ejecutar comandos inmediatamente.';
  }

  @override
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution =>
      'Los caracteres de control pueden activar acciones del terminal o ejecutar comandos.';

  @override
  String get pasteWithoutTrailingEnter => 'Pegar sin Enter final';

  @override
  String pasteLines2(String arg0) {
    return 'Pegar $arg0 líneas';
  }

  @override
  String get editText => 'Editar texto';

  @override
  String get textToSend => 'Texto que enviar';

  @override
  String get send => 'Enviar';

  @override
  String get selectEntireLine => 'Seleccionar línea completa';

  @override
  String get selectVisibleScreen => 'Seleccionar pantalla visible';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get blockSelection => 'Selección en bloque';

  @override
  String get share => 'Compartir';

  @override
  String get paste => 'Pegar';

  @override
  String get copy2 => 'Copiar';

  @override
  String get editAndSend => 'Editar y enviar';

  @override
  String get moreSelectionOptions => 'Más opciones de selección';

  @override
  String get selectionEnd => 'Fin de la selección';

  @override
  String get selectionStart => 'Inicio de la selección';

  @override
  String get clearSelection => 'Quitar selección';

  @override
  String couldNotConnectTo(String arg0) {
    return 'No se pudo conectar a $arg0';
  }

  @override
  String get couldNotCompleteOperation => 'No se pudo completar la operación';

  @override
  String get couldNotFinishOperation => 'No se pudo finalizar la operación';

  @override
  String checked(String arg0) {
    return 'Comprobado · $arg0';
  }

  @override
  String occurred(String arg0) {
    return 'Ocurrido · $arg0';
  }

  @override
  String get copyErrorLog => 'Copiar registro de errores';

  @override
  String get close2 => 'Cerrar';

  @override
  String get saveElsewhere => 'Guardar en otra ubicación';

  @override
  String get retry => 'Reintentar';

  @override
  String deletedHost(String arg0) {
    return 'Host $arg0 eliminado';
  }

  @override
  String get ok => 'Aceptar';

  @override
  String linesEnterInsertsANewline(num count, String arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '$count línea',
    );
    return '$_temp0 · Enter inserta un salto de línea$arg1';
  }

  @override
  String get ctrlEnterSends => ', Ctrl Enter envía';

  @override
  String unsupported(String arg0) {
    return ' · $arg0 no compatible';
  }

  @override
  String verifyServerKeyFor(String arg0) {
    return 'Verificar clave del servidor $arg0';
  }

  @override
  String get trustServerKey => 'Confiar en la clave del servidor';

  @override
  String authenticateWithKey2(String arg0) {
    return 'Autenticar con la clave $arg0.';
  }

  @override
  String get disconnectAll => 'Desconectar todo';

  @override
  String get disconnectAllSessions => '¿Desconectar todas las sesiones?';

  @override
  String get disconnectAll2 => 'Desconectar todo';

  @override
  String get removeServerKey => '¿Eliminar la clave del servidor?';

  @override
  String get theServerKeyWillBeVerifiedAgainOnThe =>
      'La clave del servidor se verificará de nuevo en la próxima conexión.';

  @override
  String get deleteServerKey => 'Eliminar clave del servidor';

  @override
  String sessions(String arg0) {
    return ' · Sesiones $arg0';
  }

  @override
  String get fileTransferSftp => 'Transferencia de archivos (SFTP)';

  @override
  String get favorites => 'Favoritos';

  @override
  String get quickConnect => 'Conexión rápida';

  @override
  String get createSshKeyOnThisDevice => 'Crear clave SSH en este dispositivo';

  @override
  String get sort => 'Ordenar';

  @override
  String get byColor => 'Por color';

  @override
  String get byName => 'Por nombre';

  @override
  String get help => 'Ayuda';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get couldNotPrepareAppData =>
      'No se pudieron preparar los datos de la app';

  @override
  String get preparingTilde => 'Preparando Tilde';

  @override
  String get errorDetails => 'Detalles del error';

  @override
  String get tildeHomeDirectory => 'Directorio de inicio de Tilde';

  @override
  String get inProgress => 'En curso';

  @override
  String get newOutput => 'Nueva salida';

  @override
  String get error => 'Error';

  @override
  String get notConnected => 'Sin conexión';

  @override
  String sessions2(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '$count sesión',
    );
    return ' · $_temp0';
  }

  @override
  String get connectToYourFirstServer => 'Conecta con tu primer servidor';

  @override
  String get saveAHostToConnectWithADoubleClick =>
      'Guarda un host para conectar con doble clic la próxima vez.';

  @override
  String get saveAServerToConnectQuicklyNextTime =>
      'Guarda un servidor para conectar rápidamente la próxima vez.';

  @override
  String get saveAddressUserAndAuthentication =>
      'Guardar dirección, usuario y autenticación';

  @override
  String get connectNow => 'Conectar ahora';

  @override
  String get connectByAddress => 'Conectar por dirección';

  @override
  String get enterSshUserHostInTheSearchFieldAnd =>
      'Escribe ssh user@host en el buscador y pulsa Enter';

  @override
  String get privateKeyFileSuchAsIdEd25519 =>
      'Archivo de clave privada, como id_ed25519';

  @override
  String connectingTo(String arg0, String arg1) {
    return 'Conectando a $arg0:$arg1';
  }

  @override
  String get negotiatingSshConnection => 'Negociando conexión SSH';

  @override
  String get verifyingServerKey => 'Verificando clave del servidor';

  @override
  String authenticating(String arg0) {
    return 'Autenticando a $arg0';
  }

  @override
  String get authenticated => 'Autenticado';

  @override
  String get openingTerminalSession => 'Abriendo sesión de terminal';

  @override
  String get confirmSshKeyUse => 'Confirmar uso de la clave SSH';

  @override
  String get sshPrivateKeyPassphrase =>
      'Frase de contraseña de la clave privada SSH';

  @override
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd =>
      'Conexión bloqueada porque ha cambiado la clave del servidor. Revisa y elimina manualmente la clave del servidor guardada.';

  @override
  String get preparingSshLogin => 'Preparando inicio de sesión SSH';

  @override
  String get loggedInButCouldNotSaveThePasswordSave =>
      'Se ha iniciado sesión, pero no se pudo guardar la contraseña. Vuelve a guardarla en el editor del host.';

  @override
  String sendTo(String arg0) {
    return 'Enviar a $arg0';
  }

  @override
  String get send2 => 'Enviar';

  @override
  String get terminalSize => 'Tamaño del terminal';

  @override
  String get columns => 'Columnas';

  @override
  String get rows => 'Filas';

  @override
  String get fullScreen => 'Pantalla completa';

  @override
  String get autoHideTitleBar => 'Ocultar automáticamente la barra de título';

  @override
  String get terminalSizeColumnsRows => 'Tamaño del terminal · columnas×filas';

  @override
  String get resize => 'Cambiar tamaño';

  @override
  String get text8024LeaveBlankForAutomaticSizing =>
      '80×24 · deja en blanco para ajuste automático';

  @override
  String get enterColumnsRowsSuchAs8024 =>
      'Introduce columnas×filas, por ejemplo, 80×24.';

  @override
  String get terminalLinks => 'Enlaces del terminal';

  @override
  String get noLinksOnScreen => 'No hay enlaces en pantalla.';

  @override
  String get enterText => 'Introducir texto';

  @override
  String get links => 'Enlaces';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get couldNotVerifyServerKey =>
      'No se pudo verificar la clave del servidor';

  @override
  String get couldNotLogIn => 'No se pudo iniciar sesión';

  @override
  String get couldNotOpenTerminal => 'No se pudo abrir el terminal';

  @override
  String get couldNotConnectToServer => 'No se pudo conectar al servidor';

  @override
  String connectingTo2(String arg0) {
    return 'Conectando a $arg0';
  }

  @override
  String get checkTheSavedServerKeyAndTheFingerprintProvided =>
      'Comprueba la clave del servidor guardada y la huella digital proporcionada por el administrador del servidor.';

  @override
  String get checkYourUsernameAndCredentialsIfUsingAnSsh =>
      'Comprueba el usuario y las credenciales. Si usas una clave SSH, registra la clave pública en el servidor.';

  @override
  String get checkTheServerAddressPortAndNetworkConnection =>
      'Comprueba la dirección, el puerto y la conexión de red del servidor.';

  @override
  String get connectionLog => 'Registro de conexión';

  @override
  String get deviceList => 'Lista de dispositivos';

  @override
  String get view => 'Ver';

  @override
  String get dismissBanner => 'Cerrar aviso';

  @override
  String get connectionClosed => 'Conexión cerrada';

  @override
  String get theServerEndedTheSession => 'El servidor ha finalizado la sesión';

  @override
  String get connectionEndedAfterAuthenticationFailed =>
      'La conexión se cerró tras fallar la autenticación';

  @override
  String get connectionLost => 'Conexión perdida';

  @override
  String ended(String arg0) {
    return 'Finalizado · $arg0';
  }

  @override
  String get copyOutput => 'Copiar salida';

  @override
  String sshKey(String arg0) {
    return 'Clave SSH de $arg0';
  }

  @override
  String get couldNotPrepareRegistration => 'No se pudo preparar el registro';

  @override
  String get keyToRegister => 'Clave que registrar';

  @override
  String get newBiometricKey => 'Nueva clave biométrica';

  @override
  String get createNewSshKey => 'Crear nueva clave SSH';

  @override
  String get registerSshKeyLogin => 'Registrar acceso con clave SSH';

  @override
  String keyRegistration(String arg0, String arg1) {
    return 'Registro de clave de $arg0$arg1';
  }

  @override
  String get anotherHost => 'otro host';

  @override
  String get isInProgress => ' en curso';

  @override
  String get isComplete => ' completado';

  @override
  String get registrationPreparationForThisHost =>
      'Preparar el registro de la clave en este host';

  @override
  String get installThePublicKeyThenVerifyKeyLoginWith =>
      'Instala la clave pública y verifica el acceso con clave mediante una conexión independiente.';

  @override
  String get newKeyName => 'Nombre de la nueva clave';

  @override
  String get progress => 'Progreso';

  @override
  String get installPublicKey => 'Instalar clave pública';

  @override
  String get verifyKeyLogin => 'Verificar acceso con clave';

  @override
  String get applyToHost => 'Aplicar al host';

  @override
  String get theServerRejectedTheKey => 'El servidor ha rechazado la clave';

  @override
  String get theServerRequiresAdditionalAuthentication =>
      'El servidor requiere autenticación adicional';

  @override
  String get couldNotCompleteThisStep => 'No se pudo completar este paso';

  @override
  String get installedOnServer => 'Instalada en el servidor';

  @override
  String get keyAlreadyInstalled => 'La clave ya está instalada';

  @override
  String get keyLoginVerified => 'Acceso con clave verificado';

  @override
  String get theServerRejectedThisKey => 'El servidor ha rechazado esta clave';

  @override
  String get registrationComplete => 'Registro completado';

  @override
  String usingKey(String arg0) {
    return 'Usando la clave $arg0';
  }

  @override
  String get removeSavedPasswordForThisHost =>
      'Eliminar la contraseña guardada de este host';

  @override
  String get registerAndVerify => 'Registrar y verificar';

  @override
  String get continueInBackground => 'Continuar en segundo plano';

  @override
  String get previewColorThemeFontAndMargins =>
      'Vista previa del tema, la fuente y los márgenes';

  @override
  String get srcBuildSampleMd => '\nsrc  build  sample.md';

  @override
  String get specialKeyBarPreview =>
      'Vista previa de la barra de teclas especiales';

  @override
  String get fileTransferIsAvailableForSshHosts =>
      'La transferencia de archivos está disponible para hosts SSH.';

  @override
  String get registerAKeyFromAConnectedSshSession =>
      'Registra una clave desde una sesión SSH conectada.';

  @override
  String get onlySshAndLocalConnectionsAreSupported =>
      'Solo se admiten conexiones SSH y locales.';

  @override
  String get theConnectionTypeChangedOpenANewSessionFrom =>
      'El tipo de conexión ha cambiado. Abre una nueva sesión desde Inicio.';

  @override
  String get calculatingTimeRemaining => 'Calculando tiempo restante';

  @override
  String minutesSecondsRemaining(String arg0, String arg1) {
    return 'Quedan $arg0 min y $arg1 s';
  }

  @override
  String secondsRemaining(String arg0) {
    return 'Tiempo restante: $arg0 s';
  }

  @override
  String cancelling(String arg0) {
    return '$arg0 · Cancelando…';
  }

  @override
  String get checkingSize => 'Comprobando tamaño';

  @override
  String get calculatingSpeed => 'Calculando velocidad';

  @override
  String active(String arg0) {
    return 'En curso: $arg0';
  }

  @override
  String queued(String arg0) {
    return 'En cola: $arg0';
  }

  @override
  String failed(String arg0) {
    return 'Fallidos: $arg0';
  }

  @override
  String completed(String arg0) {
    return 'Completados: $arg0';
  }

  @override
  String cancelled(String arg0) {
    return 'Cancelados: $arg0';
  }

  @override
  String get noTransfers => 'Sin transferencias';

  @override
  String get queued2 => 'En cola';

  @override
  String get paused => 'En pausa';

  @override
  String get completed2 => 'Completado';

  @override
  String get failed2 => 'Fallido';

  @override
  String get cancelOperation => 'Cancelar operación';

  @override
  String get openFolder => 'Abrir carpeta';

  @override
  String couldNotComplete(String arg0) {
    return 'No se pudo completar: $arg0';
  }

  @override
  String items2(String arg0, String arg1, String arg2) {
    return 'Elementos: $arg0 / $arg1$arg2';
  }

  @override
  String transfer(String arg0) {
    return 'Transferencia · $arg0';
  }

  @override
  String get transferQueue => 'Cola de transferencias';

  @override
  String get clearCompleted => 'Limpiar completados';

  @override
  String get collapseTransferQueue => 'Contraer cola de transferencias';

  @override
  String get expandTransferQueue => 'Expandir cola de transferencias';

  @override
  String get all => 'Todos';

  @override
  String get selectARegularFile => 'Selecciona un archivo normal.';

  @override
  String get aFileWithTheSameNameAlreadyExists =>
      'Ya existe un archivo con el mismo nombre.';

  @override
  String get theSourceFileSizeChangedDuringTransfer =>
      'El tamaño del archivo de origen cambió durante la transferencia.';

  @override
  String get aFileWithTheSameNameAppearedDuringTransfer =>
      'Se creó un archivo con el mismo nombre durante la transferencia.';

  @override
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0) {
    return 'No se pudo eliminar el archivo temporal de subida. Compruébalo en el servidor. $arg0';
  }

  @override
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0) {
    return 'No se pudo comprobar el archivo temporal de subida. Revísalo en el servidor. $arg0';
  }

  @override
  String get changePermissions => 'Cambiar permisos';

  @override
  String get read => 'Lectura';

  @override
  String get write => 'Escritura';

  @override
  String get execute => 'Ejecución';

  @override
  String get owner => 'Propietario';

  @override
  String get group => 'Grupo';

  @override
  String get other => 'Otros';

  @override
  String get octalPermissions => 'Permisos en octal';

  @override
  String get enterThreeOrFourDigitsFrom0To7 =>
      'Introduce tres o cuatro dígitos del 0 al 7.';

  @override
  String get changePermissions2 => 'Cambiar permisos';

  @override
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0) {
    return 'No se pudo abrir la carpeta. Comprueba la ruta y los permisos.\n$arg0';
  }

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get create => 'Crear';

  @override
  String get destinationFolder => 'Carpeta de destino';

  @override
  String move(String arg0) {
    return 'Mover $arg0';
  }

  @override
  String moveItems(String arg0) {
    return 'Mover selección ($arg0)';
  }

  @override
  String get parentFolder => 'Carpeta superior';

  @override
  String get folderPath => 'Ruta de la carpeta';

  @override
  String get editPath => 'Editar ruta';

  @override
  String get moveHere => 'Mover aquí';

  @override
  String permanentlyDeleteItems(String arg0) {
    return '¿Eliminar la selección permanentemente ($arg0)?';
  }

  @override
  String childItems(String arg0) {
    return 'Elementos contenidos: $arg0';
  }

  @override
  String get checkingContents => 'Comprobando contenido…';

  @override
  String get couldNotInspectFolderContentsTryAgain =>
      'No se pudo comprobar el contenido de la carpeta. Vuelve a intentarlo.';

  @override
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0) {
    return 'Elimina los elementos y el contenido de las carpetas, $arg0 en total. Esta acción no se puede deshacer.';
  }

  @override
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone =>
      'Elimina directamente, sin pasar por la papelera. Esta acción no se puede deshacer.';

  @override
  String get deletePermanently => 'Eliminar permanentemente';

  @override
  String get unknownModificationDate => 'Fecha de modificación desconocida';

  @override
  String get aFileWithTheSameNameExists =>
      'Ya existe un archivo con el mismo nombre';

  @override
  String transferringItems(String arg0, String arg1) {
    return 'Transfiriendo: $arg0 / $arg1';
  }

  @override
  String get chooseWhichFileToKeepForEachConflict =>
      'Elige qué archivo conservar en cada conflicto.';

  @override
  String get fileBeingUploaded => 'Archivo que se está subiendo';

  @override
  String get fileBeingDownloaded => 'Archivo que se está descargando';

  @override
  String get existingFileOnServer => 'Archivo existente en el servidor';

  @override
  String get existingFileOnDevice => 'Archivo existente en el dispositivo';

  @override
  String get unknownSize => 'Tamaño desconocido';

  @override
  String get keepTheExistingFileAndSkipCopyingThisFile =>
      'Conserva el archivo existente y omite la copia de este archivo.';

  @override
  String get keepBothAddTheFirstAvailableNumberStartingAt =>
      'Conserva ambos. Añade el primer número disponible, empezando por (1), antes de la extensión del archivo copiado.';

  @override
  String get overwriteTheExistingFileWithTheCopiedFileThis =>
      'Sobrescribe el archivo existente con el archivo copiado. Esta acción no se puede deshacer.';

  @override
  String get cancelCopyingKeepTheExistingFile =>
      'Cancela esta tarea de copia, incluidos los archivos restantes. Conserva los archivos existentes.';

  @override
  String applyToRemainingItems(String arg0) {
    return 'Aplicar al resto ($arg0)';
  }

  @override
  String get cancelTransfer => 'Cancelar transferencia';

  @override
  String get cancelCopy => 'Cancelar copia';

  @override
  String get loggingInForFileTransfer =>
      'Iniciando sesión para transferir archivos';

  @override
  String get couldNotLogInForFileTransfer =>
      'No se pudo iniciar sesión para transferir archivos.';

  @override
  String get previewSupportsFilesUpTo4MibDownloadThe =>
      'La vista previa admite archivos de hasta 4 MiB. Descarga el archivo para abrirlo.';

  @override
  String get saveFile => 'Guardar archivo';

  @override
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks =>
      'El editor no puede sobrescribir carpetas ni enlaces simbólicos.';

  @override
  String get serverFileChanged => 'Archivo del servidor modificado';

  @override
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0) {
    return '$arg0\nEl archivo del servidor cambió después de empezar a editar. ¿Sobrescribirlo?';
  }

  @override
  String overwriteTheExistingFile(String arg0) {
    return '$arg0\n¿Sobrescribir el archivo existente?';
  }

  @override
  String get overwrite => 'Sobrescribir';

  @override
  String get couldNotReconnectToTheServerCheckAuthenticationIn =>
      'No se pudo reconectar al servidor. Comprueba la autenticación en el explorador de archivos.';

  @override
  String get saveACopyElsewhere => 'Guardar copia en otra ubicación';

  @override
  String get saveCopy => 'Guardar copia';

  @override
  String get enterAnAbsolutePathIncludingTheFileName =>
      'Introduce una ruta absoluta que incluya el nombre del archivo.';

  @override
  String get enterAPathDifferentFromTheOriginal =>
      'Introduce una ruta distinta de la original.';

  @override
  String get newFile => 'Nuevo archivo';

  @override
  String get anItemWithTheSameNameAlreadyExists =>
      'Ya existe un elemento con el mismo nombre.';

  @override
  String get thisItemIsBeingTransferred =>
      'Este elemento se está transfiriendo.';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get change => 'Cambiar';

  @override
  String get creatingFolder => 'Creando carpeta';

  @override
  String get folderCreated => 'Carpeta creada.';

  @override
  String get deleting => 'Eliminando';

  @override
  String deletingItems(String arg0) {
    return 'Eliminando selección ($arg0)';
  }

  @override
  String deletedItems(String arg0) {
    return 'Elementos eliminados: $arg0.';
  }

  @override
  String itemsWereDeleted(String arg0) {
    return ' · Elementos ya eliminados: $arg0.';
  }

  @override
  String get changingPermissions => 'Cambiando permisos';

  @override
  String get symbolicLinkPermissionsWillNotBeChanged =>
      'No se cambiarán los permisos de los enlaces simbólicos.';

  @override
  String get permissionsChanged => 'Permisos modificados.';

  @override
  String operationCancelled(String arg0) {
    return 'Operación cancelada.$arg0';
  }

  @override
  String couldNotCompleteOperation2(String arg0) {
    return 'No se pudo completar la operación.$arg0';
  }

  @override
  String itemsPasteInTheDestinationFolder(String arg0, String arg1) {
    return 'Elementos: $arg0 · $arg1 · Pega en la carpeta de destino.';
  }

  @override
  String get cut => 'Cortar';

  @override
  String get noFilesToPaste => 'No hay archivos que pegar.';

  @override
  String get cannotMoveOrCopyToTheSameLocationOr =>
      'No se puede mover ni copiar a la misma ubicación ni dentro de la carpeta de origen.';

  @override
  String get move2 => 'Mover';

  @override
  String get copyTemporaryDownloadAndUpload =>
      'Copiar (descarga temporal y subida)';

  @override
  String get upload => 'Subir';

  @override
  String get download => 'Descargar';

  @override
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform =>
      'Esta plataforma no permite elegir una carpeta de destino.';

  @override
  String get connectionClosed2 => 'Conexión cerrada.';

  @override
  String get downloadToFileManager => 'Descargar al gestor de archivos';

  @override
  String get theTemporaryExportPathAlreadyExists =>
      'La ruta temporal de exportación ya existe.';

  @override
  String get cancelTransfersAndClose => 'Cancelar transferencias y cerrar';

  @override
  String get cancelActiveTransfersAndQueuedOperationsInThisTab =>
      '¿Cancelar las transferencias activas y las operaciones en cola de esta pestaña?';

  @override
  String get uploadFolder => 'Subir carpeta';

  @override
  String get connectionCancelled => 'Conexión cancelada';

  @override
  String get couldNotOpenFileList => 'No se pudo abrir la lista de archivos';

  @override
  String fileTransfer2(String arg0) {
    return '$arg0 · Transferencia de archivos';
  }

  @override
  String get fileList => 'Lista de archivos';

  @override
  String get checkTheFolderPathAndPermissionsThenTryAgain =>
      'Comprueba la ruta de la carpeta y los permisos y vuelve a intentarlo.';

  @override
  String get bookmarkCurrentFolder => 'Añadir carpeta actual a favoritos';

  @override
  String get recentLocations => 'Ubicaciones recientes';

  @override
  String selected(String arg0) {
    return 'Seleccionados: $arg0';
  }

  @override
  String get forward => 'Adelante';

  @override
  String get remoteFolderPath => 'Ruta de la carpeta remota';

  @override
  String get bookmarksAndRecentLocations => 'Favoritos y ubicaciones recientes';

  @override
  String get refresh => 'Actualizar';

  @override
  String get findInCurrentFolder => 'Buscar en la carpeta actual';

  @override
  String get readOnly => 'Solo lectura';

  @override
  String get discardChanges2 => 'Descartar cambios';

  @override
  String discardUnsavedChanges(String arg0) {
    return '$arg0\n¿Descartar los cambios sin guardar?';
  }

  @override
  String get doNotSave => 'No guardar';

  @override
  String get editing => 'Editando';

  @override
  String get saveCopyKeepOriginalUnchanged =>
      'Guardar copia · mantener el original';

  @override
  String savedACopyTo(String arg0) {
    return 'Se ha guardado una copia en $arg0.';
  }

  @override
  String get saved2 => 'Guardado.';

  @override
  String get couldNotOpenFile => 'No se pudo abrir el archivo';

  @override
  String couldNotOpen(String arg0) {
    return 'No se pudo abrir $arg0';
  }

  @override
  String get previewIsUnsupportedForThisFileType =>
      'No hay vista previa para este tipo de archivo.';

  @override
  String get couldNotSaveYourChangesHaveBeenKept =>
      'No se pudo guardar. Se han conservado los cambios.';

  @override
  String couldNotSave2(String arg0) {
    return 'No se pudo guardar $arg0';
  }

  @override
  String utf8LineBytes(String arg0, String arg1, String arg2) {
    return ' · UTF-8$arg0 · Líneas: $arg1 · $arg2 B';
  }

  @override
  String get unsupportedFileType => 'Tipo de archivo no compatible.';

  @override
  String get unsupportedRemoteFileType =>
      'Tipo de archivo remoto no compatible.';

  @override
  String get theTransferSourceChangedStartANewTransfer =>
      'El origen de la transferencia ha cambiado. Inicia una nueva transferencia.';

  @override
  String get anItemWithThisNameExistsAndIsNot =>
      'Existe un elemento con este nombre que no es una carpeta.';

  @override
  String get cannotOverwriteAFolderWithAFile =>
      'No se puede sobrescribir una carpeta con un archivo.';

  @override
  String get namesCannotContainPathSeparatorsOrBeOr =>
      'El nombre no puede contener separadores de ruta ni ser “.” o “..”.';

  @override
  String get aFileOrFolderWithTheSameNameAlready =>
      'Ya existe un archivo o carpeta con el mismo nombre.';

  @override
  String get cannotMoveAFolderIntoItselfOrItsDescendants =>
      'No se puede mover una carpeta a sí misma ni a sus subcarpetas.';

  @override
  String get cannotDeleteTheRootFolder =>
      'No se puede eliminar la carpeta raíz.';

  @override
  String get theServerDeniedAccessCheckTheDestinationPathPermissions =>
      'El servidor ha denegado el acceso. Comprueba los permisos de la ruta de destino.';

  @override
  String get theFileOrFolderNoLongerExists =>
      'El archivo o la carpeta ya no existe.';

  @override
  String get serverConnectionLost =>
      'Se ha perdido la conexión con el servidor.';

  @override
  String get theServerCouldNotCompleteTheOperation =>
      'El servidor no pudo completar la operación.';

  @override
  String get theServerIsNotRespondingCheckTheAddressAnd =>
      'El servidor no responde. Comprueba la dirección y la red.';

  @override
  String get theServerDidNotAuthenticateYouCheckYourUsername =>
      'El servidor no ha podido autenticarte. Comprueba el usuario, la clave y la contraseña.';

  @override
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0) {
    return 'El servidor ha rechazado la conexión$arg0. Comprueba SSH y los ajustes del puerto.';
  }

  @override
  String onPort(String arg0) {
    return ' en el puerto $arg0';
  }

  @override
  String get checkTheServerConnection =>
      'No se pudo comunicar con el servidor. Comprueba la conexión de red.';

  @override
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport =>
      'Error inesperado. Copia los detalles siguientes y contacta con soporte.';

  @override
  String get transferCancelled => 'Transferencia cancelada.';

  @override
  String get invalidFileName => 'Nombre de archivo no válido.';

  @override
  String get theFileWasNotReceivedCompletely =>
      'El archivo no se recibió por completo.';

  @override
  String get size => 'Tamaño';

  @override
  String get modified => 'Modificado';

  @override
  String get permissions => 'Permisos';

  @override
  String get ownerUid => 'UID del propietario';

  @override
  String get groupGid => 'GID del grupo';

  @override
  String get showHiddenFilesAndFolders => 'Mostrar archivos y carpetas ocultos';

  @override
  String get descending => 'Orden descendente';

  @override
  String get visibleColumns => 'Columnas visibles';

  @override
  String get preview => 'Vista previa';

  @override
  String get move3 => 'Mover…';

  @override
  String get copyPath => 'Copiar ruta';

  @override
  String get info => 'Información';

  @override
  String get changePermissions3 => 'Cambiar permisos…';

  @override
  String get fileInformation => 'Información del archivo';

  @override
  String get path => 'Ruta';

  @override
  String get type2 => 'Tipo';

  @override
  String get folder => 'Carpeta';

  @override
  String get symbolicLink => 'Enlace simbólico';

  @override
  String get file => 'Archivo';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get location => 'Ubicación';

  @override
  String selected2(String arg0, String arg1) {
    return 'Seleccionados: $arg0 · $arg1';
  }

  @override
  String get parentFolderBackspace => 'Carpeta superior (Backspace)';

  @override
  String get loading => 'Cargando…';

  @override
  String get noFilesToDisplay => 'No hay archivos que mostrar.';

  @override
  String get noMatchingFiles => 'No hay archivos coincidentes.';

  @override
  String get applyNewName => 'Aplicar nuevo nombre';

  @override
  String actions(String arg0) {
    return 'Acciones de $arg0';
  }

  @override
  String items3(String arg0, String arg1) {
    return 'Elementos: $arg0$arg1';
  }

  @override
  String hiddenFiltered(String arg0) {
    return ' · Ocultos/filtrados: $arg0';
  }

  @override
  String copy3(String arg0) {
    return 'Copia de $arg0';
  }

  @override
  String hostsWillUseTheAppDefaultProfile(String arg0) {
    return 'Hosts que pasarán a usar el perfil predeterminado de la app: $arg0.';
  }

  @override
  String get deleteThisProfile => 'Eliminar este perfil.';

  @override
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0) {
    return 'Se conservarán las conexiones de los hosts ($arg0 en total), pero se eliminará la contraseña compartida.';
  }

  @override
  String delete2(String arg0) {
    return 'Eliminar $arg0';
  }

  @override
  String get setAsDefault => 'Establecer como predeterminado';

  @override
  String add2(String arg0) {
    return 'Añadir $arg0';
  }

  @override
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts =>
      'Comparte usuario, clave y contraseña entre varios hosts.';

  @override
  String get default2 => ' · Predeterminado';

  @override
  String get noHostsUsingThis => 'Ningún host usa este elemento';

  @override
  String hosts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts',
      one: '$count host',
    );
    return '$_temp0';
  }

  @override
  String get privateKeyPassphrase => 'Frase de contraseña de la clave privada';

  @override
  String get leaveBlankIfThereIsNoPassphrase =>
      'Deja el campo en blanco si no hay frase de contraseña.';

  @override
  String get deleteKey2 => 'Eliminar clave';

  @override
  String deleteKey3(String arg0) {
    return '¿Eliminar la clave $arg0?';
  }

  @override
  String get savePublicKeyFile => 'Guardar archivo de clave pública';

  @override
  String get addKeyFile => 'Añadir archivo de clave';

  @override
  String get newKey => 'Nueva clave';

  @override
  String get couldNotCompleteKeyOperation =>
      'No se pudo completar la operación de la clave';

  @override
  String get importedPrivateKeysAreUsedFromProtectedAppStorage =>
      'Las claves privadas importadas se usan desde el almacenamiento protegido de la app. Las frases de contraseña guardadas están protegidas por el llavero de iOS.';

  @override
  String get privateKeyFilesAreUsedFromTheirOriginalLocation =>
      'Los archivos de clave privada se usan desde su ubicación original. Las frases de contraseña guardadas están protegidas por tu cuenta de Windows.';

  @override
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot =>
      'Las claves privadas se crean en Android Keystore y no se pueden exportar. Las claves antiguas se conservan desactivadas.';

  @override
  String get disabled => 'Desactivado';

  @override
  String options(String arg0) {
    return 'Opciones de $arg0';
  }

  @override
  String get deleteForwarding => 'Eliminar reenvío';

  @override
  String deleteSettingsFor(String arg0) {
    return '¿Eliminar los ajustes de $arg0?';
  }

  @override
  String forwarding2(String arg0) {
    return '$arg0 · Reenvío';
  }

  @override
  String get addForwarding => 'Añadir reenvío';

  @override
  String get sessionToControl => 'Sesión que controlar';

  @override
  String switchChangesApplyImmediately(String arg0) {
    return '$arg0 · Los cambios del interruptor se aplican al instante';
  }

  @override
  String get defaultOnConnection => 'Valor predeterminado al conectar';

  @override
  String get couldNotLoadForwarding => 'No se pudo cargar el reenvío';

  @override
  String get socks4UnsupportedChangeToSocks5 =>
      'SOCKS4 no compatible · Cambia a SOCKS5';

  @override
  String get removeServerKeyTrust =>
      'Retirar confianza en la clave del servidor';

  @override
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1) {
    return '$arg0:$arg1\nLa clave del servidor se verificará en la próxima conexión.';
  }

  @override
  String get noTrustedServerKeys => 'No hay claves de servidor de confianza.';

  @override
  String get use => 'Usar';

  @override
  String get editPalette => 'Editar paleta';

  @override
  String get export => 'Exportar';

  @override
  String get defaultTheme => 'Tema predeterminado';

  @override
  String get customTheme => 'Tema personalizado';

  @override
  String get nameForDuplicateTheme => 'Nombre de la copia del tema';

  @override
  String get themeName => 'Nombre del tema';

  @override
  String get deleteTheme => 'Eliminar tema';

  @override
  String deleteTheme2(String arg0) {
    return '¿Eliminar el tema $arg0?';
  }

  @override
  String get newThemeName => 'Nombre del nuevo tema';

  @override
  String get newTheme => 'Nuevo tema';

  @override
  String get import => 'Importar';

  @override
  String get textColor => 'Color del texto';

  @override
  String get backgroundColor => 'Color de fondo';

  @override
  String get cursorAndAppAccent => 'Cursor y color de acento de la app';

  @override
  String get couldNotLoadColorTheme => 'No se pudo cargar el tema de colores';

  @override
  String get makeACopyToEditTheColors =>
      'Crea una copia para editar los colores.';

  @override
  String get lsSrcBuildSampleMd => '~ \$ ls\nsrc  build  sample.md\n';

  @override
  String get defaultColors => 'Colores predeterminados';

  @override
  String get lowContrastAgainstBackground => 'Contraste bajo con el fondo';

  @override
  String get ansiPalette => 'Paleta ANSI';

  @override
  String ansiColor(String arg0) {
    return 'Color ANSI $arg0';
  }

  @override
  String get findServer => 'Buscar servidor';

  @override
  String get verifyServerKey => 'Verificar clave del servidor';

  @override
  String seconds(String arg0) {
    return '$arg0 s';
  }

  @override
  String get couldNotOpenAdPrivacySettingsTryAgain =>
      'No se pudieron abrir los ajustes de privacidad de anuncios. Vuelve a intentarlo.';

  @override
  String get ad => 'Anuncio';

  @override
  String get adPrivacySettings => 'Privacidad de anuncios';

  @override
  String get googleFontsMonospace => 'Google Fonts · Monoespaciadas';

  @override
  String get searchSettings => 'Buscar ajustes';

  @override
  String get keyboard => 'Teclado';

  @override
  String get gestures => 'Gestos';

  @override
  String get connectionsAndNotifications => 'Conexiones y notificaciones';

  @override
  String get securityAndBackup => 'Seguridad y copias de seguridad';

  @override
  String get manageFonts => 'Gestionar fuentes';

  @override
  String get specialKeyBar => 'Barra de teclas especiales';

  @override
  String specialKeys(String arg0) {
    return 'Teclas especiales: $arg0';
  }

  @override
  String twoFingerHorizontalSwipe(String arg0) {
    return 'Deslizar horizontalmente con dos dedos · $arg0';
  }

  @override
  String get tmuxWindows => 'Ventanas de tmux';

  @override
  String get disabled2 => 'Desactivado';

  @override
  String get defaultTerminal => 'Terminal predeterminado';

  @override
  String get notificationsAndBell => 'Notificaciones y campana';

  @override
  String sshKeys2(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count claves SSH',
      one: '$count clave SSH',
    );
    return '$_temp0';
  }

  @override
  String get helpAndLogs2 => 'Ayuda y registros';

  @override
  String get horizontalMargins => 'Márgenes horizontales';

  @override
  String get lines => 'líneas';

  @override
  String get appTheme => 'Tema de la app';

  @override
  String get systemTheme => 'Tema del sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get font => 'Fuente';

  @override
  String get orientation => 'Orientación';

  @override
  String get alwaysRotate => 'Girar siempre';

  @override
  String get portrait => 'Vertical';

  @override
  String get landscape => 'Horizontal';

  @override
  String get hideStatusBar => 'Ocultar barra de estado';

  @override
  String get specialKeyLayout => 'Distribución de teclas especiales';

  @override
  String get showWhenKeyboardIsClosed => 'Mostrar con el teclado cerrado';

  @override
  String get whenPressingCtrlOrAlt => 'Al pulsar Ctrl o Alt';

  @override
  String get once => 'Una vez';

  @override
  String get sticky => 'Fijar';

  @override
  String get stickyAltOnly => 'Fijar solo Alt';

  @override
  String get keyboardToggleButton => 'Botón para alternar teclado';

  @override
  String get twoFingerHorizontalSwipe2 =>
      'Deslizar horizontalmente con dos dedos';

  @override
  String get doNothing => 'No hacer nada';

  @override
  String get switchSessions => 'Cambiar de sesión';

  @override
  String get switchTmuxWindows => 'Cambiar de ventana de tmux';

  @override
  String get prefixKey => 'Tecla de prefijo';

  @override
  String get twoFingerVerticalSwipe => 'Deslizar verticalmente con dos dedos';

  @override
  String get scroll => 'Desplazar';

  @override
  String get volumeButtonsChangeFontSize =>
      'Cambiar tamaño de fuente con botones de volumen';

  @override
  String get specialKeyVibration => 'Vibración de teclas especiales';

  @override
  String get defaultTerminalProfile => 'Perfil predeterminado del terminal';

  @override
  String get manageTerminalProfiles => 'Gestionar perfiles del terminal';

  @override
  String itemCount(String arg0) {
    return '$arg0';
  }

  @override
  String get appearance => 'Apariencia';

  @override
  String get terminalTypeTerm => 'Tipo de terminal (TERM)';

  @override
  String get addTerminalType => 'Añadir tipo de terminal';

  @override
  String get terminalType => 'Tipo de terminal';

  @override
  String get keepScreenAwakeWhileConnected =>
      'Mantener pantalla encendida durante la conexión';

  @override
  String get theTerminalScreenWillStayAwake =>
      'La pantalla del terminal permanecerá encendida';

  @override
  String get preventWiFiSleep => 'Evitar suspensión de Wi-Fi';

  @override
  String get usesMoreBattery => 'Consume más batería';

  @override
  String get backgroundConnectionNotification =>
      'Notificación de conexión en segundo plano';

  @override
  String get pinnedWhileConnected => 'Fija durante la conexión';

  @override
  String get terminalBell => 'Campana del terminal';

  @override
  String get whenTheBellRings => 'Cuando suene la campana';

  @override
  String get ignore => 'Ignorar';

  @override
  String get sound => 'Sonido';

  @override
  String get vibration => 'Vibración';

  @override
  String get soundAndVibration => 'Sonido y vibración';

  @override
  String get volume => 'Volumen';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notificationPermissionRequired =>
      'Se necesita permiso de notificaciones';

  @override
  String get allow => 'Permitir';

  @override
  String get enableConnectionNotifications =>
      'Activar notificaciones de conexión';

  @override
  String get allowBellAndDisconnectionNotifications =>
      'Permitir avisos de campana y desconexión';

  @override
  String get bellInBackground => 'Campana en segundo plano';

  @override
  String get onDisconnect => 'Al desconectar';

  @override
  String get androidNotificationSettings =>
      'Ajustes de notificaciones de Android';

  @override
  String get notificationsOff => 'Notificaciones desactivadas';

  @override
  String get notificationsAllowed => 'Notificaciones permitidas';

  @override
  String get lock => 'Bloqueo';

  @override
  String get unlockWhenStartingTheApp => 'Exigir desbloqueo al iniciar la app';

  @override
  String get setUpAScreenLockFirst =>
      'Configura primero un bloqueo de pantalla';

  @override
  String get fingerprintOrScreenLock => 'Huella dactilar o bloqueo de pantalla';

  @override
  String get keysAndServers => 'Claves y servidores';

  @override
  String get configurationFile => 'Archivo de configuración';

  @override
  String get exportHosts => 'Exportar hosts';

  @override
  String get importHosts => 'Importar hosts';

  @override
  String get selectDefaultFont => 'Seleccionar fuente predeterminada';

  @override
  String fontSample(String arg0) {
    return '$arg0 Aa';
  }

  @override
  String get bundledWithApp => 'Incluida en la app';

  @override
  String get monospaceFont => 'Fuente monoespaciada';

  @override
  String get deleteFont => 'Eliminar fuente';

  @override
  String get deleteThisFontFile => '¿Eliminar este archivo de fuente?';

  @override
  String get removeFont => 'Quitar fuente';

  @override
  String get preparingFont => 'Preparando fuente';

  @override
  String get importFontFile => 'Importar archivo de fuente';

  @override
  String get findOnGoogleFonts => 'Buscar en Google Fonts';

  @override
  String get onlyMonospaceFontsAreShown =>
      'Solo se muestran fuentes monoespaciadas';

  @override
  String settings2(String arg0) {
    return 'Ajustes › $arg0';
  }

  @override
  String get couldNotSaveSettings => 'No se pudieron guardar los ajustes';

  @override
  String get resetSpecialKeyBar =>
      '¿Restablecer la barra de teclas especiales?';

  @override
  String get restoreTheDefaultHeightKeyOrderAndVisibility =>
      'Restaura la altura, el orden y la visibilidad predeterminados de las teclas.';

  @override
  String get longPressToDragTapToHide =>
      'Mantén pulsado para arrastrar · Toca para ocultar';

  @override
  String get hiddenKeys => 'Teclas ocultas';

  @override
  String get tapAKeyToMoveItHere => 'Toca una tecla para moverla aquí';

  @override
  String get combineF1F12IntoFn => 'Agrupar F1–F12 en Fn';

  @override
  String get height => 'Altura';

  @override
  String get small => 'Pequeño';

  @override
  String get large => 'Grande';

  @override
  String get default3 => 'Predeterminado';

  @override
  String get escAndCtrlStayOnTheLeftKeyboardFn =>
      'Esc y Ctrl permanecen a la izquierda; teclado, Fn y Tab permanecen a la derecha.';

  @override
  String get flutterLibraryLicenses => 'Licencias de las bibliotecas Flutter';

  @override
  String get tips => 'Consejos';

  @override
  String get licensesAndTerms => 'Licencias y condiciones';

  @override
  String get projectAndContact => 'Proyecto y contacto';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get diagnosticLogs => 'Registros de diagnóstico';

  @override
  String get searchLogs => 'Buscar en los registros';

  @override
  String get saveNativeCrashLog => 'Guardar registro de fallo nativo';

  @override
  String get warning => 'Advertencia';

  @override
  String get couldNotLoadLogs => 'No se pudieron cargar los registros';

  @override
  String get onlyAndroidKeystoreSshKeysAreSupported =>
      'Solo se admiten claves SSH de Android Keystore';

  @override
  String get onlyP256AndroidKeystoreKeysAreSupported =>
      'Solo se admiten claves P-256 de Android Keystore';

  @override
  String get invalidEcdsaSignature => 'Firma ECDSA no válida';

  @override
  String get invalidEcdsaSignatureValues => 'Valores de firma ECDSA no válidos';

  @override
  String get invalidX509PublicKey => 'Clave pública X509 no válida';

  @override
  String get invalidPublicKeyBitString =>
      'Cadena de bits de la clave pública no válida';

  @override
  String get invalidRsaPublicKey => 'Clave pública RSA no válida';

  @override
  String get invalidEcCurve => 'Curva EC no válida';

  @override
  String get invalidUncompressedEcPoint => 'Punto EC sin comprimir no válido';

  @override
  String get invalidEd25519PublicKey => 'Clave pública Ed25519 no válida';

  @override
  String unsupportedSshPublicKeyAlgorithm(String arg0) {
    return 'Algoritmo de clave pública SSH no compatible: $arg0';
  }

  @override
  String get unsupportedSshEcCurve => 'Curva EC SSH no compatible';

  @override
  String get invalidDerSequence => 'Secuencia DER no válida';

  @override
  String get privateKeyExportIsNotSupported =>
      'No se admite exportar la clave privada';

  @override
  String get publicKeyIsUnavailable => 'Clave pública no disponible';

  @override
  String unsupportedTerminalKey(String arg0) {
    return 'Tecla de terminal no compatible: $arg0';
  }

  @override
  String get disconnectBeforeReconnecting =>
      'Desconecta antes de volver a conectar';

  @override
  String get localShellIsNotOpen => 'El shell local no está abierto';

  @override
  String get unknownModifier => 'Tecla modificadora desconocida';

  @override
  String unsupportedLocalTerminalOperation(String arg0) {
    return 'Operación de terminal local no compatible: $arg0';
  }

  @override
  String get invalidSshPublicKeyLine => 'Línea de clave pública SSH no válida';

  @override
  String get serverDidNotConfirmPublicKeyRegistration =>
      'El servidor no ha confirmado el registro de la clave pública.';

  @override
  String get logInToASavedSshHostBeforeRegistering =>
      'Inicia sesión en un host SSH guardado antes de registrar la clave.';

  @override
  String get theSelectedSshKeyNoLongerExists =>
      'La clave SSH seleccionada ya no existe.';

  @override
  String get aUniqueBiometricKeyNameIsRequired =>
      'Introduce un nombre único para la clave biométrica.';

  @override
  String get theOriginalSshConnectionIsNoLongerAuthenticated =>
      'La conexión SSH original ya no está autenticada.';

  @override
  String get keyOnlyLoginWasNotCompletedTheServerMay =>
      'No se pudo iniciar sesión solo con la clave. El servidor puede requerir autenticación adicional. Los ajustes de acceso no se han modificado.';

  @override
  String get theSavedHostNoLongerExists => 'El host guardado ya no existe.';

  @override
  String get theHostAddressChangedDuringRegistrationItsLoginSettings =>
      'La dirección del host cambió durante el registro. Los ajustes de acceso no se han modificado.';

  @override
  String get invalidPtyDimensions => 'Dimensiones de PTY no válidas';

  @override
  String get sshTargetIsRequired => 'Indica el destino SSH';

  @override
  String get sshSessionWasClosed => 'La sesión SSH se ha cerrado';

  @override
  String get sshSessionIsNotConnected => 'La sesión SSH no está conectada';

  @override
  String get sshSessionsCannotBeReused =>
      'Las sesiones SSH no se pueden reutilizar';

  @override
  String get noAddressForRequestedIpVersion =>
      'No hay dirección para la versión IP solicitada';

  @override
  String get sshHopConnectionTimedOut =>
      'Se agotó el tiempo de la conexión SSH a través del host de salto';

  @override
  String get sshSessionHasNoShell => 'La sesión SSH no tiene un shell';

  @override
  String get sshSessionRequestTimedOut =>
      'Se agotó el tiempo de solicitud de la sesión SSH';

  @override
  String get invalidForwardBindPort =>
      'Puerto de escucha del reenvío no válido';

  @override
  String get invalidForwardDestination => 'Destino de reenvío no válido';

  @override
  String get remoteForwardingRequestTimedOut =>
      'Se agotó el tiempo de solicitud del reenvío remoto';

  @override
  String get remoteForwardingWasRefused =>
      'El reenvío remoto ha sido rechazado';

  @override
  String get forwardConnectionTimedOut =>
      'Se agotó el tiempo de conexión del reenvío';

  @override
  String get remoteForwardDestinationTimedOut =>
      'Se agotó el tiempo de conexión con el destino del reenvío remoto';

  @override
  String get remoteForwardingCancellationWasRefused =>
      'Se ha rechazado la cancelación del reenvío remoto';

  @override
  String get sshAuthenticationCancelled => 'Autenticación SSH cancelada';

  @override
  String get concurrentSshAuthenticationPrompt =>
      'Ya hay una solicitud de autenticación SSH en curso';

  @override
  String get sessionDisposed => 'Sesión finalizada';

  @override
  String get disconnectBeforeRefreshingSshConfiguration =>
      'Desconecta antes de actualizar la configuración SSH';

  @override
  String get couldNotUnlockTheSelectedKey =>
      'No se pudo desbloquear la clave seleccionada.';

  @override
  String get logInToThisServerBeforeRegisteringAKey =>
      'Inicia sesión en este servidor antes de registrar la clave.';

  @override
  String get sshShellIsNotOpen => 'El shell SSH no está abierto';

  @override
  String get sshIsNotConnected => 'SSH no está conectado';

  @override
  String get portForwardIsMissing =>
      'Falta la configuración del reenvío de puertos';

  @override
  String get unsupportedSshForwardType => 'Tipo de reenvío SSH no compatible';

  @override
  String unsupportedAppSshOperation(String arg0) {
    return 'Operación SSH de la app no compatible: $arg0';
  }

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get timedOutReadingWindowsSshSettings =>
      'Se agotó el tiempo de lectura de los ajustes SSH de Windows.';

  @override
  String couldNotReadWindowsSshSettings(String arg0) {
    return 'No se pudieron leer los ajustes SSH de Windows. $arg0';
  }

  @override
  String get windowsUserProfilePathIsUnavailable =>
      'La ruta del perfil de usuario de Windows no está disponible.';

  @override
  String unsupportedSshKeyPathVariable(String arg0) {
    return 'Variable de ruta de clave SSH no compatible: $arg0';
  }

  @override
  String couldNotImportFiles(String arg0) {
    return 'No se pudieron importar los archivos: $arg0';
  }

  @override
  String uploadTo(String arg0) {
    return 'Subir a $arg0';
  }

  @override
  String get currentFolder => 'Carpeta actual';

  @override
  String get windowsUserDataFolderIsUnavailable =>
      'La carpeta de datos de usuario de Windows no está disponible.';

  @override
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0) {
    return 'No se pudieron proteger las credenciales con la cuenta de Windows. $arg0';
  }

  @override
  String get altDrag => 'Arrastrar con Alt';

  @override
  String get keyUp => 'Arriba';

  @override
  String get keyDown => 'Abajo';

  @override
  String get keyHome => 'Inicio de línea';

  @override
  String get keyEnd => 'Fin de línea';

  @override
  String get keyPageUp => 'Página anterior';

  @override
  String get keyPageDown => 'Página siguiente';

  @override
  String get keyInsert => 'Insertar';

  @override
  String get keyDelete => 'Suprimir';

  @override
  String get skipCopy => 'Omitir';

  @override
  String get keepBothFiles => 'Conservar ambos';

  @override
  String get cancelJobNoApplyAll =>
      'La opción de aplicar a los archivos restantes no está disponible al cancelar la tarea.';

  @override
  String get editAuthentication => 'Editar autenticación';

  @override
  String get serverMessage => 'Mensaje del servidor';

  @override
  String get cancellingOperation => 'Cancelando…';

  @override
  String get transferHeading => 'Transferencias';

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
