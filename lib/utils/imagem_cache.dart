import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Cache de [MemoryImage] por string base64.
///
/// Decodificar e criar um novo `MemoryImage` a cada build gera uma nova
/// identidade de provider, o que faz o cache de imagens do Flutter re-decodificar
/// o JPEG inteiro. Reutilizar a mesma instância por base64 evita esse custo.
final Map<String, MemoryImage> _cacheFotoMemoria = {};

/// Retorna um [MemoryImage] cacheado para a string base64 informada.
/// Strings vazias retornam `null` (nenhuma imagem).
MemoryImage? fotoMemoria(String base64) {
  if (base64.isEmpty) return null;
  return _cacheFotoMemoria.putIfAbsent(
    base64,
    () => MemoryImage(base64Decode(base64)),
  );
}
