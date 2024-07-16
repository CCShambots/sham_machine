import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sham_states/constants.dart';
import 'package:sham_states/network_tree/networktables_tree_row.dart';
import 'package:sham_states/services/ip_address_util.dart';
import 'package:sham_states/services/log.dart';
import 'package:sham_states/services/nt4_client.dart';
import 'package:sham_states/services/nt_connection.dart';
import 'package:sham_states/settings.dart';
import 'package:sham_states/settings_dialog.dart';
import 'package:sham_states/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state_widget.dart';

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

  runApp(ShamStates(preferences: preferences));
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

class ShamStates extends StatefulWidget {
  final SharedPreferences preferences;

  const ShamStates({super.key, required this.preferences});

  @override
  State<ShamStates> createState() => _ShamStatesState();
}

class _ShamStatesState extends State<ShamStates> {
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
        title: 'ShamStates v$version',
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

  const HomePage({super.key, required this.prefs});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SharedPreferences prefs;

  String selectedDirectory = "";
  List<StateMachine> stateMachines = [];
  StateMachine? currentMachine;
  late Widget interactiveViewer;

  final NetworkTableTreeRow root = NetworkTableTreeRow(topic: '/', rowName: '');
  int previousTopicsLength = 0;

  bool wasConnected = false;

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

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        // Perform any state updates here
      });
    });
  }

  void createRows(NT4Topic nt4Topic) {
    String topic = nt4Topic.name;

    List<String> rows = topic.substring(1).split('/');
    NetworkTableTreeRow? current;
    String currentTopic = '';

    for (String row in rows) {
      currentTopic += '/$row';

      bool lastElement = currentTopic == topic;

      if (current != null) {
        if (current.hasRow(row)) {
          current = current.getRow(row);
        } else {
          current = current.createNewRow(
              topic: currentTopic,
              name: row,
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      } else {
        if (root.hasRow(row)) {
          current = root.getRow(row);
        } else {
          current = root.createNewRow(
              topic: currentTopic,
              name: row,
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //Load all NT4 topics
    List<NT4Topic> topics = [];

    for (NT4Topic topic in ntConnection.nt4Client.announcedTopics.values) {
      if (topic.name == 'Time') {
        continue;
      }

      topics.add(topic);
    }

    for (NT4Topic topic in topics) {
      createRows(topic);
    }

    if (topics.length != previousTopicsLength) {
      previousTopicsLength = topics.length;
      for (var e in stateMachines) {
        e.loadSubsystemSubscriptions();
      }
      setState(() {});
    }


    return Scaffold(
        appBar: AppBar(
          title: Text(selectedDirectory.split("\\").last),
          actions: [
            StreamBuilder(
                stream: ntConnection.connectionStatus(),
                builder: (context, snapshot) {
                  bool connected = snapshot.data ?? false;

                  if (connected != wasConnected) {
                    // Schedule a callback for the end of this frame
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        wasConnected = connected;
                      });
                    });
                  }

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
                      return stateMachineList(machine);
                    }),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              currentMachine!.name,
                              style: StyleConstants.titleStyle,
                            ),
                          ),
                          currentMachine!.isEnabled() ? const Tooltip(
                            message: "Enabled",
                            child: Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 48,
                            ),
                          ) : const Tooltip(
                            message: "Not Enabled",
                            child: Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 48,
                            ),
                          )
                        ]),
                        Expanded(child: interactiveViewer)
                      ],
                    )
                  : Center(
                  child: Text(
                    "Select a State Machine",
                    style: StyleConstants.titleStyle,
                  ),
                                      ),
            ),
          ],
        ));
  }

  ListTile stateMachineList(StateMachine machine) {
    bool isInNT = false;

    try {
      isInNT = machine.getMachineInNT().topic.isNotEmpty;
    } catch (e) {}

    return ListTile(
      title: Text(machine.name),
      subtitle: Text(machine.statesEnum),
      trailing: isInNT
          ? const Tooltip(
              message: "Found on NT",
              child: Icon(Icons.power, color: Colors.green))
          : const Tooltip(
              message: "Not Found on NT",
              child: Icon(Icons.power_off, color: Colors.red)),
      onTap: () {
        setCurrentMachine(machine);
      },
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
        selectedDirectory = projectPath;
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
              fileContents: contents,
              root: root));
        }
      }
    });

    setState(() {
      stateMachines = machines;
    });

    if (stateMachines.isNotEmpty) {
      setCurrentMachine(machines.first);
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
              return StateWidget(machine: currentMachine, id: id);
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
