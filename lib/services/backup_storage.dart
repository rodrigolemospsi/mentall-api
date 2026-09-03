// Exporta a implementação de armazenamento de backup conforme a plataforma:
// em navegador usa o stub web (sem escrita em arquivo); caso contrário, o io.
export 'backup_storage_io.dart'
    if (dart.library.html) 'backup_storage_web.dart';
