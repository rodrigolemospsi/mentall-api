// Exporta a implementação de compartilhamento de PDFs conforme a plataforma:
// no mobile/desktop usa arquivos temporários + share sheet; no navegador o
// stub avisa que a exportação só existe no aplicativo.
export 'exportacao_arquivos_io.dart'
    if (dart.library.html) 'exportacao_arquivos_web.dart';
