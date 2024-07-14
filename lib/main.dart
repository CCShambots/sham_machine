import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sham_machine/constants.dart';
import 'package:sham_machine/services/ip_address_util.dart';
import 'package:sham_machine/services/log.dart';
import 'package:sham_machine/services/nt_connection.dart';
import 'package:sham_machine/settings.dart';
import 'package:sham_machine/settings_dialog.dart';
import 'package:sham_machine/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {

    await logger.initialize();

  final String appFolderPath = (await getApplicationSupportDirectory()).path;

  // Prevents data loss if shared_preferences.json gets corrupted
  // More info and original implementation: https://github.com/flutter/flutter/issues/89211#issuecomment-915096452
  SharedPreferences preferences;
  try {
    preferences = await SharedPreferences.getInstance();

    // Store a copy of user's preferences on the disk
    await _backupPreferences(appFolderPath);
  } catch (error) {
    logger.warning(
        'Failed to get shared preferences instance, attempting to retrieve from backup',
        error);
    // Remove broken preferences files and restore previous settings
    await _restorePreferencesFromBackup(appFolderPath);
    preferences = await SharedPreferences.getInstance();
  }

  // NTWidgetBuilder.ensureInitialized();

  Settings.ipAddress =
      preferences.getString(PrefKeys.ipAddress) ?? Settings.ipAddress;

  ntConnection.nt4Connect(Settings.ipAddress);


  runApp(ShamMachine(preferences: preferences));
}

/// Makes a backup copy of the current shared preferences file.
Future<void> _backupPreferences(String appFolderPath) async {
  try {
    final String original = '$appFolderPath\\shared_preferences.json';
    final String backup = '$appFolderPath\\shared_preferences_backup.json';

    if (await File(backup).exists()) await File(backup).delete(recursive: true);
    await File(original).copy(backup);

    logger.info('Backup up shared_preferences.json to $backup');
  } catch (_) {
    /* Do nothing */
  }
}

/// Removes current version of shared_preferences file and restores previous
/// user settings from a backup file (if it exists).
Future<void> _restorePreferencesFromBackup(String appFolderPath) async {
  try {
    final String original = '$appFolderPath\\shared_preferences.json';
    final String backup = '$appFolderPath\\shared_preferences_backup.json';

    await File(original).delete(recursive: true);

    if (await File(backup).exists()) {
      // Check if current backup copy is not broken by looking for letters and "
      // symbol in it to replace it as an original Settings file
      final String preferences = await File(backup).readAsString();
      if (preferences.contains('"') && preferences.contains(RegExp('[A-z]'))) {
        logger.info('Restoring shared_preferences from backup file at $backup');
        await File(backup).copy(original);
      }
    }
  } catch (_) {
    /* Do nothing */
  }
}

class ShamMachine extends StatefulWidget {
  final SharedPreferences preferences;

  ShamMachine({required this.preferences});

  @override
  State<ShamMachine> createState() => _ShamMachineState();
}

class _ShamMachineState extends State<ShamMachine> {
  String version = "";


  @override
  void initState() {
    super.initState();
    initVersion();

  }

  void initVersion() async {
    PackageInfo info = await PackageInfo.fromPlatform();

    setState(() {
      version = info.version;
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ShamMachine v$version',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          scaffoldBackgroundColor: Theme.of(context).colorScheme.surface,
        ),
        darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue, brightness: Brightness.dark),
            brightness: Brightness.dark),
        home: HomePage(
          prefs: widget.preferences,
        ),
      );
}

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;

  HomePage({required this.prefs});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SharedPreferences prefs;

  String selectedDirectory = "";
  List<StateMachine> stateMachines = [];
  StateMachine? currentMachine;
  late Widget interactiveViewer;

  @override
  void initState() {
    loadProjectPath().then((projectPreset) {
      if (!projectPreset) {
        selectRobotProject();
      } else {
        loadProject();
      }
    });

    prefs = widget.prefs;
  }

  @override
  Widget build(BuildContext context) {
    print(currentMachine?.graph);

    return Scaffold(
        appBar: AppBar(
          title: Text(selectedDirectory.split("\\").last),
          actions: [
            StreamBuilder(
                stream: ntConnection.connectionStatus(),
                builder: (context, snapshot) {
                  bool connected = snapshot.data ?? false;

                  String connectedText = (connected)
                      ? 'Network Tables: Connected (${prefs.getString(PrefKeys.ipAddress)})'
                      : 'Network Tables: Disconnected';

                  return IconButton(
                    tooltip: connectedText,
                    icon: Icon(
                      (connected) ? Icons.wifi : Icons.wifi_off,
                      color: (connected) ? Colors.green : Colors.red,
                    ),
                    onPressed: () {
                      _displaySettingsDialog(context);
                    },
                  );
                }),
            IconButton(
                tooltip: "Select Robot Project",
                onPressed: () {
                  selectRobotProject();
                },
                icon: const Icon(Icons.folder)),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh Project Data",
              onPressed: () {
                loadProject();
              },
            )
          ],
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Row(
          children: [
            Flexible(
              flex: 1,
              child: Container(
                // color: Colors.grey,
                decoration: StyleConstants.shadedDecoration(context),
                child: ListView(
                  children: [
                    Center(
                        child: Text(
                      "State Machines",
                      style: StyleConstants.subtitleStyle,
                    )),
                    ...stateMachines.map((machine) {
                      return ListTile(
                        title: Text(machine.name),
                        subtitle: Text(machine.statesEnum),
                        onTap: () {
                          setCurrentMachine(machine);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            Flexible(
              flex: 4,
              child: currentMachine != null
                  ? Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Wrap(children: [
                          Text(
                            currentMachine!.name,
                            style: StyleConstants.titleStyle,
                          )
                        ]),
                        Expanded(child: interactiveViewer)
                      ],
                    )
                  : Expanded(
                      child: Center(
                      child: Text(
                        "Select a State Machine",
                        style: StyleConstants.titleStyle,
                      ),
                    )),
            ),
          ],
        ));
  }

  Widget rectangleWidget(int id) {
    bool isOmni = currentMachine!.isOmni(id);

    return InkWell(
      onTap: () {
        print('clicked');
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
                color: !isOmni ? Colors.blue : Colors.green, spreadRadius: 1),
          ],
        ),
        child: Text(
          currentMachine!.getStateFromNodeId(id),
          style: StyleConstants.subtitleStyle,
        ),
      ),
    );
  }

  final builder = BuchheimWalkerConfiguration();

  Future<void> selectRobotProject() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        this.selectedDirectory = selectedDirectory;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString("projectPath", selectedDirectory);

      loadProject();
    }
  }

  Future<bool> loadProjectPath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? projectPath = prefs.getString("projectPath");

    if (projectPath != null) {
      setState(() {
        this.selectedDirectory = projectPath;
      });

      return true;
    } else {
      return false;
    }
  }

  Future<void> loadProject() async {
    final stateMachineRegex = RegExp(
        r'public[\n ]+class[\n ]+([a-zA-z]+)[\n ]+extends[\n ]+StateMachine<(.+)>');

    Directory directory = Directory(selectedDirectory);

    List<FileSystemEntity> files = directory.listSync(recursive: true);

    files = files.where((e) {
      return e.path.endsWith(".java");
    }).toList();

    List<StateMachine> machines = [];

    await Future.forEach(files, (file) async {
      if (file is File) {
        String contents = await file.readAsString();

        final match = stateMachineRegex.firstMatch(contents);

        if (match != null) {
          machines.add(StateMachine(
              name: match.group(1)!,
              statesEnum: match.group(2)!,
              fileContents: contents));
        }
      }
    });

    setState(() {
      stateMachines = machines;
    });

    if (stateMachines.isNotEmpty) {
      setCurrentMachine(machines.last);
    }
  }

  void setCurrentMachine(StateMachine machine) {
    setState(() {
      currentMachine = machine;

      interactiveViewer = InteractiveViewer(
          key: UniqueKey(),
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.01,
          maxScale: 5.6,
          child: GraphView(
            // graph: machine!.graph,
            graph: machine.graph,
            algorithm: FruchtermanReingoldAlgorithm(),
            paint: Paint()
              ..color = Colors.white
              // ..strokeWidth = 1
              ..style = PaintingStyle.stroke,
            builder: (Node node) {
              // I can decide what widget should be shown here based on the id
              var id = node.key?.value as int;
              return rectangleWidget(id);
            },
          ));
    });
  }

  void _updateIPAddress(String newIPAddress) async {
    if (newIPAddress == Settings.ipAddress) {
      return;
    }
    await prefs.setString(PrefKeys.ipAddress, newIPAddress);
    Settings.ipAddress = newIPAddress;

    setState(() {
      ntConnection.changeIPAddress(newIPAddress);
    });
  }

  void _displaySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        preferences: widget.prefs,
        onTeamNumberChanged: (String? data) async {
          if (data == null) {
            return;
          }

          int? newTeamNumber = int.tryParse(data);

          if (newTeamNumber == null ||
              (newTeamNumber == Settings.teamNumber &&
                  Settings.teamNumber != 9999)) {
            return;
          }

          await prefs.setInt(PrefKeys.teamNumber, newTeamNumber);
          Settings.teamNumber = newTeamNumber;

          switch (Settings.ipAddressMode) {
            case IPAddressMode.roboRIOmDNS:
              _updateIPAddress(
                  IPAddressUtil.teamNumberToRIOmDNS(newTeamNumber));
              break;
            case IPAddressMode.teamNumber:
              _updateIPAddress(IPAddressUtil.teamNumberToIP(newTeamNumber));
              break;
            default:
              setState(() {});
              break;
          }
        },
        onIPAddressModeChanged: (mode) async {
          if (mode == Settings.ipAddressMode) {
            return;
          }
          await prefs.setInt(PrefKeys.ipAddressMode, mode.index);

          Settings.ipAddressMode = mode;

          switch (mode) {
            case IPAddressMode.driverStation:
              String? lastAnnouncedIP = ntConnection.dsClient.lastAnnouncedIP;

              if (lastAnnouncedIP == null) {
                break;
              }

              _updateIPAddress(lastAnnouncedIP);
              break;
            case IPAddressMode.roboRIOmDNS:
              _updateIPAddress(
                  IPAddressUtil.teamNumberToRIOmDNS(Settings.teamNumber));
              break;
            case IPAddressMode.teamNumber:
              _updateIPAddress(
                  IPAddressUtil.teamNumberToIP(Settings.teamNumber));
              break;
            case IPAddressMode.localhost:
              _updateIPAddress('localhost');
              break;
            default:
              setState(() {});
              break;
          }
        },
        onIPAddressChanged: (String? data) async {
          if (data == null || data == Settings.ipAddress) {
            return;
          }

          _updateIPAddress(data);
        },
        onDefaultPeriodChanged: (value) async {
          if (value == null) {
            return;
          }
          double? newPeriod = double.tryParse(value);

          if (newPeriod == null || newPeriod == Settings.defaultPeriod) {
            return;
          }

          await prefs.setDouble(PrefKeys.defaultPeriod, newPeriod);

          setState(() => Settings.defaultPeriod = newPeriod);
        },
        onDefaultGraphPeriodChanged: (value) async {
          if (value == null) {
            return;
          }
          double? newPeriod = double.tryParse(value);

          if (newPeriod == null || newPeriod == Settings.defaultGraphPeriod) {
            return;
          }

          await prefs.setDouble(PrefKeys.defaultGraphPeriod, newPeriod);

          setState(() => Settings.defaultGraphPeriod = newPeriod);
        },
      ),
    );
  }
}
