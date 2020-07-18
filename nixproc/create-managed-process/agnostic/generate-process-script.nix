{ createProcessScript, writeTextFile, stdenv, daemon, basePackages
, runtimeDir, tmpDir, forceDisableUserChange
}:

let
  daemonPkg = daemon; # Circumvent name conflict with the parameter in the next function header
in

{ name
, description
, initialize
, daemon
, daemonArgs
, instanceName
, pidFile
, foregroundProcess
, foregroundProcessArgs
, path
, environment
, directory
, umask
, nice
, user
, dependencies
, credentials
, overrides
, postInstall
}:

let
  util = import ../util {
    inherit (stdenv) lib;
  };

  _environment = util.appendPathToEnvironment {
    inherit environment;
    path = basePackages ++ [ daemonPkg ] ++ path;
  };

  _pidFile =
    if pidFile == null
      then if instanceName == null
        then null
        else if user == null || user == "root"
          then "${runtimeDir}/${instanceName}.pid"
          else "${tmpDir}/${instanceName}.pid"
    else pidFile;

  _user = util.determineUser {
    inherit user forceDisableUserChange;
  };

  pidFilesDir = util.determinePIDFilesDir {
    user = _user;
    inherit runtimeDir tmpDir;
  };

  invocationCommand =
    if (daemon != null) then util.invokeDaemon {
      process = daemon;
      args = daemonArgs;
      su = "su";
      user = _user;
    }
    else if (foregroundProcess != null) then util.daemonizeForegroundProcess {
      daemon = "daemon";
      process = foregroundProcess;
      args = foregroundProcessArgs;
      pidFile = _pidFile;
      user = _user;
      inherit pidFilesDir;
    }
    else throw "I don't know how to start this process!";
in
createProcessScript (stdenv.lib.recursiveUpdate ({
  inherit name dependencies credentials postInstall;

  process = writeTextFile {
    name = "${name}-process-wrapper";
    executable = true;
    text = ''
      #! ${stdenv.shell} -e
    ''
    + util.printShellEnvironmentVariables {
      environment = _environment;
      allowSystemPath = true;
    }
    + stdenv.lib.optionalString (umask != null) ''
      umask ${umask}
    ''
    + stdenv.lib.optionalString (directory != null) ''
      cd ${directory}
    ''
    + stdenv.lib.optionalString (nice != null) ''
      nice -n ${toString nice}
    ''
    + stdenv.lib.optionalString (initialize != null) ''
      ${initialize}
    ''
    + "exec ${invocationCommand}";
  };
} // stdenv.lib.optionalAttrs (_pidFile != null) {
  pidFile = _pidFile;
}) overrides)
