
import 'package:graphview/GraphView.dart';

class StateMachine {
  final String name;
  final String statesEnum;
  final String fileContents;

  late final Graph graph;

  final Map<String, Node> states = {};
  final List<Edge> transitions = [];

  final List<String> omniTransitions = [];

  StateMachine(
      {required this.name,
      required this.statesEnum,
      required this.fileContents}) {
        
    graph = Graph();

    loadStates();

    loadTransitions();
    loadCommutativeTransitions();
    loadOmniTransitions();

    addTransitionsToGraph();

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

    matches.forEach((e) {
      String from = e.group(1)!;
      String to = e.group(2)!;

      addTranstion(from, to);
    });
  }

  void loadCommutativeTransitions() {
    final transitionRegex =
        RegExp(r'addCommutativeTransition *\( *(.+) *, *(.+)[ ,)]');

    final matches = transitionRegex.allMatches(fileContents);

    matches.forEach((e) {
      String first = e.group(1)!;
      String second = e.group(2)!;

      addTranstion(first, second);
      addTranstion(second, first);
    });
  }

  void loadOmniTransitions() {
    
    final transitionRegex = RegExp(r'addOmniTransition *\( *(.+) *[,)]');

    final matches = transitionRegex.allMatches(fileContents);

    matches.forEach((e) {
      String state = e.group(1)!;

      omniTransitions.add(state.split(".").last);
    });
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
            if(!e.contains(",")) e += ",";

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
