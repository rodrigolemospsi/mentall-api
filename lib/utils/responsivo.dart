import 'package:flutter/material.dart';

class Responsivo {
  Responsivo._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;
}
