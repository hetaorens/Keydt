import 'package:flutter/material.dart';

import 'package:keyviz/config/config.dart';
import 'package:keyviz/windows/shared/shared.dart';

import 'views/views.dart';
import 'widgets/widgets.dart';

class SettingsWindow extends StatefulWidget {
  const SettingsWindow({super.key});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  SettingsTab _currentTab = SettingsTab.general;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      height: 544,
      padding: const EdgeInsets.all(defaultPadding),
      decoration: _backgroundDecor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SideBar(
            currentTab: _currentTab,
            onChange: (tab) => setState(() => _currentTab = tab),
          ),
          const SmallRowGap(),
          Expanded(
            child: DecoratedBox(
              decoration: _innerDecor,
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(defaultPadding * 1.5),
                child: StyleTabView(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _backgroundDecor => BoxDecoration(
        color: context.colorScheme.background,
        borderRadius: defaultBorderRadius,
        border: Border.all(
          color: context.colorScheme.outline,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, defaultPadding),
            blurRadius: defaultPadding * 2,
          )
        ],
      );

  BoxDecoration get _innerDecor => BoxDecoration(
        color: context.colorScheme.secondaryContainer,
        borderRadius: defaultBorderRadius,
      );
}
