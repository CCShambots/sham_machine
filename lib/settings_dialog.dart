import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:sham_machine/services/ip_address_util.dart';
import 'package:sham_machine/services/nt_connection.dart';
import 'package:sham_machine/services/text_formatter_builder.dart';
import 'package:sham_machine/settings.dart';
import 'package:sham_machine/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:sham_machine/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatefulWidget {
  final SharedPreferences preferences;

  final Function(String? data)? onIPAddressChanged;
  final Function(String? data)? onTeamNumberChanged;
  final Function(IPAddressMode mode)? onIPAddressModeChanged;
  final Function(String? value)? onDefaultPeriodChanged;
  final Function(String? value)? onDefaultGraphPeriodChanged;

  const SettingsDialog({
    super.key,
    required this.preferences,
    this.onTeamNumberChanged,
    this.onIPAddressModeChanged,
    this.onIPAddressChanged,
    this.onDefaultPeriodChanged,
    this.onDefaultGraphPeriodChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      content: Container(
        constraints: const BoxConstraints(
          maxHeight: 275,
          maxWidth: 725,
        ),
        child: Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ..._generalSettings(),
              const Divider(),
              ..._ipAddressSettings(),
            ],
          ),
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
          Flexible(
            child: DialogTextInput(
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
          ),
    ];
  }

  List<Widget> _ipAddressSettings() {
    return [
      const Align(
        alignment: Alignment.topLeft,
        child: Text('IP Address Settings'),
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


  List<Widget> _networkTablesSettings() {
    return [
      const Align(
        alignment: Alignment.topLeft,
        child: Text('Network Tables Settings'),
      ),
      const SizedBox(height: 5),
      Flexible(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              child: DialogTextInput(
                initialText:
                    (widget.preferences.getDouble(PrefKeys.defaultPeriod) ??
                            Settings.defaultPeriod)
                        .toString(),
                label: 'Default Period',
                onSubmit: (value) async {
                  await widget.onDefaultPeriodChanged?.call(value);
                  setState(() {});
                },
                formatter: TextFormatterBuilder.decimalTextFormatter(),
              ),
            ),
            Flexible(
              child: DialogTextInput(
                initialText: (widget.preferences
                            .getDouble(PrefKeys.defaultGraphPeriod) ??
                        Settings.defaultGraphPeriod)
                    .toString(),
                label: 'Default Graph Period',
                onSubmit: (value) async {
                  widget.onDefaultGraphPeriodChanged?.call(value);
                  setState(() {});
                },
                formatter: TextFormatterBuilder.decimalTextFormatter(),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
