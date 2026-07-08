import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> selecionarArquivoJsonWeb() async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json';
  input.addEventListener('change', (_) {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.addEventListener('load', (_) {
      completer.complete(reader.result as String?);
    });
    reader.addEventListener('error', (_) {
      completer.complete(null);
    });
    reader.readAsText(file);
  });
  input.click();
  return completer.future;
}

void baixarJsonWeb(String conteudo, String nomeArquivo) {
  final blob = html.Blob([conteudo], 'application/json');
  final url = html.Url.createObjectUrl(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = nomeArquivo;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
