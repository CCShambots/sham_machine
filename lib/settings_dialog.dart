import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sham_states/constants.dart';
import 'package:sham_states/services/ip_address_util.dart';
import 'package:sham_states/services/nt_connection.dart';
import 'package:sham_states/settings.dart';
import 'package:sham_states/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:sham_states/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatefulWidget {
  final SharedPreferences preferences;

  final Function(String? data)? onIPAddressChanged;
  final Function(String? data)? onTeamNumberChanged;
  final Function(IPAddressMode mode)? onIPAddressModeChanged;

  const SettingsDialog({
    super.key,
    required this.preferences,
    this.onTeamNumberChanged,
    this.onIPAddressModeChanged,
    this.onIPAddressChanged
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Align(alignment: Alignment.center, child: Text('Settings')),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      content: Container(
        constraints: const BoxConstraints(
          maxHeight: 275,
          maxWidth: 725,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Text('Version $version'),
            ),
            ..._generalSettings(),
            const Divider(),
            ..._ipAddressSettings(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  List<Widget> _generalSettings() {
    return [
      DialogTextInput(
        initialText:
            widget.preferences.getInt(PrefKeys.teamNumber)?.toString() ??
                Settings.teamNumber.toString(),
        label: 'Team Number',
        onSubmit: (data) async {
          await widget.onTeamNumberChanged?.call(data);
          setState(() {});
        },
        formatter: FilteringTextInputFormatter.digitsOnly,
      ),
    ];
  }

  List<Widget> _ipAddressSettings() {
    return [
      Align(
        alignment: Alignment.center,
        child: Text('IP Address Settings', style: StyleConstants.h3Style,),
      ),
      const SizedBox(height: 5),
      const Text('IP Address Mode'),
      DialogDropdownChooser<IPAddressMode>(
        onSelectionChanged: (mode) {
          if (mode == null) {
            return;
          }

          widget.onIPAddressModeChanged?.call(mode);

          setState(() {});
        },
        choices: IPAddressMode.values,
        initialValue: Settings.ipAddressMode,
      ),
      const SizedBox(height: 5),
      StreamBuilder(
          stream: ntConnection.dsConnectionStatus(),
          initialData: ntConnection.isDSConnected,
          builder: (context, snapshot) {
            bool dsConnected = tryCast(snapshot.data) ?? false;

            return DialogTextInput(
              enabled: Settings.ipAddressMode == IPAddressMode.custom ||
                  (Settings.ipAddressMode == IPAddressMode.driverStation &&
                      !dsConnected),
              initialText: widget.preferences.getString(PrefKeys.ipAddress) ??
                  Settings.ipAddress,
              label: 'IP Address',
              onSubmit: (String? data) async {
                await widget.onIPAddressChanged?.call(data);
                setState(() {});
              },
            );
          })
    ];
  }

  // List<Widget> _networkTablesSettings() {
  //   return [
  //     const Align(
  //       alignment: Alignment.topLeft,
  //       child: Text('Network Tables Settings'),
  //     ),
  //     const SizedBox(height: 5),
  //     Flexible(
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //         children: [
  //           Flexible(
  //             child: DialogTextInput(
  //               initialText:
  //                   (widget.preferences.getDouble(PrefKeys.defaultPeriod) ??
  //                           Settings.defaultPeriod)
  //                       .toString(),
  //               label: 'Default Period',
  //               onSubmit: (value) async {
  //                 await widget.onDefaultPeriodChanged?.call(value);
  //                 setState(() {});
  //               },
  //               formatter: TextFormatterBuilder.decimalTextFormatter(),
  //             ),
  //           ),
  //           Flexible(
  //             child: DialogTextInput(
  //               initialText: (widget.preferences
  //                           .getDouble(PrefKeys.defaultGraphPeriod) ??
  //                       Settings.defaultGraphPeriod)
  //                   .toString(),
  //               label: 'Default Graph Period',
  //               onSubmit: (value) async {
  //                 widget.onDefaultGraphPeriodChanged?.call(value);
  //                 setState(() {});
  //               },
  //               formatter: TextFormatterBuilder.decimalTextFormatter(),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   ];
  // }
}
