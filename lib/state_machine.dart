import 'package:graphview/GraphView.dart';
import 'package:sham_states/network_tree/networktables_tree_row.dart';
import 'package:sham_states/services/nt4_client.dart';
import 'package:sham_states/services/nt_connection.dart';

class StateMachine {
  final String name;
  final String statesEnum;
  final String fileContents;

  final NetworkTableTreeRow root;
  late final NT4Subscription? enabledSubscription;
  late final NT4Subscription? currentStateSubscription;
  late final NT4Subscription? desiredStateSubscription;
  late final NT4Subscription? flagsSubscription;

  NT4Topic? selectedStateSetterTopic;
  late final String _setStateTopic;

  late final Graph graph;

  final Map<String, Node> states = {};
  final List<Edge> transitions = [];

  final List<String> omniTransitions = [];

  StateMachine(
      {required this.name,
      required this.statesEnum,
      required this.fileContents,
      required this.root}) {
    graph = Graph();

    _setStateTopic = "/SmartDashboard/$name State Chooser/selected";

    loadStates();

    loadTransitions();
    loadCommutativeTransitions();
    loadOmniTransitions();

    addTransitionsToGraph();
  }

  void loadSubsystemSubscriptions() {
    loadEnabledSubscription();
    loadStateSubscription();
    loadDesiredSubcription();
    loadFlagsSubscription();
    loadTargetStateTopic();
  }

  NetworkTableTreeRow getMachineInNT() {
    return root.getRow("AdvantageKit").getRow("RealOutputs").getRow(name);
  }

  void createTopicIfNull() {
    selectedStateSetterTopic ??= ntConnection.getTopicFromName(_setStateTopic);
  }

  void setTargetState(String state) {
    try {
      bool publishTopic = selectedStateSetterTopic == null ||
          !ntConnection.isTopicPublished(selectedStateSetterTopic!);

      createTopicIfNull();

      if (selectedStateSetterTopic == null) {
        return;
      }

      if (publishTopic) {
        ntConnection.nt4Client.publishTopic(selectedStateSetterTopic!);
      }

      ntConnection.updateDataFromTopic(selectedStateSetterTopic!, state);
    } catch (e) {
      print("Failed to set target state for $name");
    }
  }

  void loadTargetStateTopic() {
    try {
      bool publishTopic = selectedStateSetterTopic == null ||
          !ntConnection.isTopicPublished(selectedStateSetterTopic!);

      createTopicIfNull();

      if (publishTopic) {
        // var row = root
        //     .getRow("SmartDashboard")
        //     .getRow("${name} State Chooser")
        //     .getRow("default");

        // var defaultSub = ntConnection.subscribe(row.topic);

        ntConnection.nt4Client.publishNewTopic(_setStateTopic, "string");
      }

      print("Loaded state setter for $name");
    } catch (e) {
      print("Failed to load active state setter topic for $name");
    }
  }

  void loadFlagsSubscription() {
    try {
      var row = getMachineInNT();

      String topic = row.getRow("flags").topic;
      flagsSubscription = ntConnection.subscribe(topic);
    } catch (e) {
      // print("Failed to load flags subscription for $name");
    }
  }

  void loadDesiredSubcription() {
    try {
      var row = getMachineInNT();

      String topic = row.getRow("desired").topic;
      desiredStateSubscription = ntConnection.subscribe(topic);
    } catch (e) {
      // print("Failed to load desired subscription for $name");
    }
  }

  void loadStateSubscription() {
    try {
      var row = getMachineInNT();

      String topic = row.getRow("state").topic;
      currentStateSubscription = ntConnection.subscribe(topic);
    } catch (e) {
      // print("Failed to load current state subscription for $name");
    }
  }

  void loadEnabledSubscription() {
    try {
      var row = getMachineInNT();

      String topic = row.getRow("enabled").topic;
      enabledSubscription = ntConnection.subscribe(topic);
    } catch (e) {
      // print("Failed to load enabled subscription for $name");
    }
  }

  bool isEnabled() {
    try {
      return enabledSubscription?.currentValue as bool;
    } catch (e) {
      return false;
    }
  }

  String getCurrentState() {
    try {
      return currentStateSubscription?.currentValue as String;
    } catch (e) {
      return "";
    }
  }

  String getDesiredState() {
    try {
      return desiredStateSubscription?.currentValue as String;
    } catch (e) {
      return "";
    }
  }

  bool isFlagSet(String flag) {
    try {
      return (flagsSubscription?.currentValue as List<String>).contains(flag);
    } catch (e) {
      return false;
    }
  }

  bool isOmni(int id) {
    return omniTransitions.contains(getStateFromNodeId(id));
  }

  String getStateFromNodeId(int id) {
    return states.keys.toList()[id];
  }

  void addTransitionsToGraph() {
    for (Edge edge in transitions) {
      graph.addEdge(states[edge.from]!, states[edge.to]!);
    }
  }

  void loadTransitions() {
    final transitionRegex = RegExp(r'addTransition *\( *(.+) *, *(.+)[ ,)]');

    final matches = transitionRegex.allMatches(fileContents);

    for (var e in matches) {
      String from = e.group(1)!;
      String to = e.group(2)!;

      addTranstion(from, to);
    }
  }

  void loadCommutativeTransitions() {
    final transitionRegex =
        RegExp(r'addCommutativeTransition *\( *(.+) *, *(.+)[ ,)]');

    final matches = transitionRegex.allMatches(fileContents);

    for (var e in matches) {
      String first = e.group(1)!;
      String second = e.group(2)!;

      addTranstion(first, second);
      addTranstion(second, first);
    }
  }

  void loadOmniTransitions() {
    final transitionRegex = RegExp(r'addOmniTransition *\( *(.+) *[,)]');

    final matches = transitionRegex.allMatches(fileContents);

    for (var e in matches) {
      String state = e.group(1)!;

      omniTransitions.add(state.split(".").last);
    }
  }

  void addTranstion(String from, String to) {
    from = from.split(".").last;
    to = to.split(".").last;

    if (states.keys.contains(from) && states.keys.contains(to)) {
      transitions.add(Edge(from: from, to: to));
    }
  }

  void loadStates() {
    final statesEnumRegex =
        RegExp(r'public[\n ]+enum[\n ]+([a-zA-z]+)[\n ]+{([\S\s]+?)[;}]');

    final match = statesEnumRegex.firstMatch(fileContents);

    if (match != null) {
      // Remove leading and trailing whitespace from the entire input
      String statesInput = match.group(2)!.trim();

      // Extract lines that contain enum values
      List<String> lines = statesInput
          .split('\n')
          .where((line) {
            // Check if the line contains an enum value (ignoring comments)
            return line.trim().isNotEmpty && !line.trim().startsWith('//');
          })
          .map((e) => e.trim())
          .map((e) => e.split("(").first)
          .map((e) {
            if (!e.contains(",")) e += ",";

            return e;
          })
          .toList();

      // Join lines into a single string to handle multiple enum values on one line
      String enumDeclaration = lines.join('');

      // Extract individual enum values
      List<String> enumValues = enumDeclaration
          .split(',')
          .map((enumValue) {
            return enumValue.trim();
          })
          .where((enumValue) => enumValue.isNotEmpty)
          .toList();

      for (String val in enumValues) {
        Node node = Node.Id(enumValues.indexOf(val));
        states.putIfAbsent(val, () => node);

        graph.addNode(node);
      }
    }
  }
}

class Edge {
  final String from;
  final String to;

  Edge({required this.from, required this.to});
}
