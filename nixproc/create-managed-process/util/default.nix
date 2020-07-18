{lib}:

rec {
  /*
   * Composes a PATH environment variable from a collection of packages by
   * translating their paths to bin/ sub folders
   */
  composePathEnvVariable = {path}:
    builtins.concatStringsSep ":" (map (package: "${package}/bin") path);

  /*
   * Appends the bin/ sub folders in the packages in path as a PATH environment
   * variable to the environment.
   */
  appendPathToEnvironment = {environment, path}:
    lib.optionalAttrs (path != []) {
      PATH = composePathEnvVariable {
        inherit path;
      };
    } // environment;

  /*
   * Prints escaped export statements that configure environment variables
   *
   * Parameters:
   * environment: attribute set in which the keys are the environment variables names and the values to environment variable values
   * allowSystemPath: whether to allow access to the original system PATH
   */
  printShellEnvironmentVariables = {environment, allowSystemPath ? true}:
    lib.concatMapStrings (name:
      let
        value = builtins.getAttr name environment;
      in
      ''
        export ${name}=${lib.escapeShellArg value}${lib.optionalString (allowSystemPath && name == "PATH") ":$PATH"}
      ''
    ) (builtins.attrNames environment);

  /*
   * Determines the actual user name
   */
  determineUser = {user, forceDisableUserChange}:
    if forceDisableUserChange then null else user;

  /*
   * Determines the preferred directory in which PID files should be stored.
   * For privileged users it is in the runtime dir, unprivileged users use the
   * temp dir.
   */
  determinePIDFilesDir = {user, runtimeDir, tmpDir}:
    if user == null then runtimeDir else tmpDir;

  /*
   * Auto-generates the path to the preferred PID file if none has been
   * specified.
   */
  autoGeneratePIDFilePath = {pidFile, instanceName, pidFilesDir}:
    if pidFile == null then
      if instanceName == null then null
      else "${pidFilesDir}/${instanceName}.pid"
    else pidFile;

  /*
   * Creates a shell command invocation that deamonizes a foreground process by
   * using libslack's daemon command.
   */
  daemonizeForegroundProcess = {daemon, process, args, pidFile ? null, pidFilesDir, user ? null}:
    "${daemon} --unsafe --inherit"
    + (if pidFile == null then " --pidfiles ${pidFilesDir} --name $(basename ${process})" else " --pidfile ${pidFile}")
    + lib.optionalString (user != null) " --user ${user}"
    + " -- ${process} ${lib.escapeShellArgs args}";

  /*
   * Creates a daemon command invocation that escapes parameters and changes the
   * user, if needed.
   */
  invokeDaemon = {process, args, su, user ? null}:
    let
      invocation = "${process} ${lib.escapeShellArgs args}";
    in
    if user == null then invocation
    else "${su} ${user} -c ${lib.escapeShellArgs [ invocation ]}";

  /*
   * Creates credential configuration files for users and groups, or returns
   * null if user changing was disabled.
   */
  createCredentialsOrNull = {createCredentials, credentials, forceDisableUserChange}:
    if credentials == {} || forceDisableUserChange then null else createCredentials credentials;
}
