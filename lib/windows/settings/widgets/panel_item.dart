import 'package:flutter/material.dart';

import 'package:keyviz/config/config.dart';

class PanelItem extends StatelessWidget {
  const PanelItem({
    super.key,
    required this.title,
    required this.action,
    this.asRow = true,
    this.enabled = true,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget action;
  final bool asRow;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: defaultPadding * .25),
        if (subtitle != null)
          Text(
            subtitle!,
            style: context.textTheme.bodyMedium,
          ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : .4,
      child: asRow
          ? Row(
              crossAxisAlignment: subtitle == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: label,
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: action,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: defaultPadding * .75),
                action,
              ],
            ),
    );
  }
}
