import 'package:flutter/material.dart';

import 'mentall_colors.dart';

PreferredSizeWidget appBarPadrao({
  required BuildContext context,
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    title: Text(title),
    backgroundColor: context.corPrimaria,
    foregroundColor: context.corOnPrimaria,
    elevation: 0,
    centerTitle: false,
    actions: actions,
    bottom: bottom,
  );
}
