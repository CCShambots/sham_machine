import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sham_machine/constants.dart';
import 'package:sham_machine/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
        home: HomePage(),
      );
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedDirectory = "";
  List<StateMachine> stateMachines = [];
  StateMachine? currentMachine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(selectedDirectory.split("\\").last),
          actions: [
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
                          setState(() {
                            currentMachine = machine;
                          });
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
                  Wrap(children: [Text(currentMachine!.name, style: StyleConstants.titleStyle,)]),

                  Expanded(
                          child: InteractiveViewer(
                              constrained: false,
                              boundaryMargin: const EdgeInsets.all(100),
                              minScale: 0.01,
                              maxScale: 5.6,
                              child: GraphView(
                                graph: currentMachine!.graph,
                                algorithm: FruchtermanReingoldAlgorithm(),
                                paint: Paint()
                                  ..color = Colors.green
                                  // ..strokeWidth = 1
                                  ..style = PaintingStyle.stroke,
                                builder: (Node node) {
                                  // I can decide what widget should be shown here based on the id
                                  var id = node.key?.value as int;
                                  return rectangleWidget(id);
                                },
                              )),
                        )
                      
                ],
              ): Expanded(
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

  Random r = Random();

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
            BoxShadow(color: !isOmni ? Colors.blue: Colors.green, spreadRadius: 1),
          ],
        ),
        child: Text(currentMachine!.getStateFromNodeId(id), style: StyleConstants.subtitleStyle,),
        // child: Container()
      ),
    );
  }

  final builder = BuchheimWalkerConfiguration();

  @override
  void initState() {
    loadProjectPath().then((projectPreset) {
      if (!projectPreset) {
        selectRobotProject();
      } else {
        loadProject();
      }
    });
  }

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
      currentMachine = stateMachines.last;
    }
  }
}
