import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sham_machine/constants.dart';
import 'package:sham_machine/main.dart';
import 'package:sham_machine/state_machine.dart';

class StateWidget extends StatefulWidget {
  const StateWidget({
    super.key,
    required this.machine,
    required this.id,
  });

  final StateMachine? machine;
  final int id;

  @override
  State<StateWidget> createState() => _StateWidgetState();
}

class _StateWidgetState extends State<StateWidget> {
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isOmni = widget.machine!.isOmni(widget.id);

    String stateName = widget.machine!.getStateFromNodeId(widget.id);

    bool isCurrentState = widget.machine!.getCurrentState() == stateName;

    return Animate(
      onPlay: isCurrentState ? (controller) => controller.repeat() : null,
      effects: isCurrentState
          ? [
              const ShimmerEffect(),
              const ScaleEffect(begin: Offset(1, 1), end: Offset(1.1, 1.1)),
              const ThenEffect(),
              const ScaleEffect(begin: Offset(1.1, 1.1), end: Offset(1, 1))
            ]
          : [],
      child: Tooltip(
        message: isCurrentState ? "Current State" : "Click to go to state",
        child: InkWell(
            onTap: () {
              widget.machine!.setTargetState(stateName);
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: !isOmni ? Colors.blue : Colors.green,
                      spreadRadius: 1),
                ],
              ),
              child: Text(
                stateName,
                style: StyleConstants.subtitleStyle,
              ),
            )),
      ),
    );
  }
}
