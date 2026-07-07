import 'package:flutter/material.dart';

class EstadoVazioPacientes extends StatelessWidget {
  final String termoSingular;
  final String termoPlural;
  final String nenhumOuNenhuma;
  final String primeiroOuPrimeira;
  final String cadastradoOuCadastrada;
  final bool listaArquivada;

  const EstadoVazioPacientes({
    super.key,
    required this.termoSingular,
    required this.termoPlural,
    required this.nenhumOuNenhuma,
    required this.primeiroOuPrimeira,
    required this.cadastradoOuCadastrada,
    required this.listaArquivada,
  });

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    final titulo = listaArquivada
        ? 'Nenhum cadastro arquivado'
        : '$nenhumOuNenhuma $termoSingular $cadastradoOuCadastrada';

    final mensagem = listaArquivada
        ? 'Quando algum $termoSingular for arquivado, aparecerá aqui para consulta ou restauração.'
        : 'Toque no botão + para cadastrar seu $primeiroOuPrimeira $termoSingular.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              listaArquivada
                  ? Icons.archive_outlined
                  : Icons.psychology_alt_outlined,
              size: 72,
              color: corPrincipal.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
