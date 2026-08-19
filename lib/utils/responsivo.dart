import 'package:flutter/material.dart';

enum TamanhoTela { compacto, medio, expandido }

class Responsivo {
  Responsivo._();

  static const double breakpointTablet = 600;
  static const double breakpointDesktop = 1024;

  static double largura(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static bool isTablet(BuildContext context) =>
      largura(context) >= breakpointTablet;

  static bool isDesktop(BuildContext context) =>
      largura(context) >= breakpointDesktop;

  static TamanhoTela tamanho(BuildContext context) {
    final w = largura(context);
    if (w >= breakpointDesktop) return TamanhoTela.expandido;
    if (w >= breakpointTablet) return TamanhoTela.medio;
    return TamanhoTela.compacto;
  }
}
