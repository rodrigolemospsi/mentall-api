import 'package:flutter/material.dart';
import '../utils/mentall_colors.dart';

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
              size: 64,
              color: context.corPrimaria.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.corTextoHeading,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: TextStyle(
                fontSize: 14,
                color: context.corTextoMuted,
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
