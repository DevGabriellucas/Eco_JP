import 'package:eco_jp/models/rota_coleta_model.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:eco_jp/utils/texto.dart';
import 'package:flutter/material.dart';

/// Abre uma lista pesquisável com todos os bairros do cronograma de coleta.
/// Retorna o bairro escolhido (ou `null` se o usuário fechar sem escolher).
Future<String?> mostrarBuscaBairroSheet(
  BuildContext context,
  MapController controller,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BuscaBairroSheet(controller: controller),
  );
}

class _BuscaBairroSheet extends StatefulWidget {
  final MapController controller;

  const _BuscaBairroSheet({required this.controller});

  @override
  State<_BuscaBairroSheet> createState() => _BuscaBairroSheetState();
}

class _BuscaBairroSheetState extends State<_BuscaBairroSheet> {
  String _busca = '';

  List<String> get _bairrosFiltrados {
    final termo = removerAcentos(_busca).toLowerCase().trim();
    final todos = widget.controller.bairrosOrdenados;
    if (termo.isEmpty) return todos;
    return todos
        .where((b) => removerAcentos(b).toLowerCase().contains(termo))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _bairrosFiltrados;
    // Ocupa boa parte da tela e sobe junto com o teclado.
    final altura = MediaQuery.of(context).size.height * 0.78;
    final fundoTeclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: fundoTeclado),
      child: SizedBox(
        height: altura,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Consultar coleta por bairro',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                autofocus: false,
                onChanged: (valor) => setState(() => _busca = valor),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Digite o nome do bairro',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? const _ListaVazia()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final bairro = filtrados[i];
                        return _BairroTile(
                          bairro: bairro,
                          agendas: widget.controller.agendasDoBairro(bairro),
                          onTap: () => Navigator.of(context).pop(bairro),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaVazia extends StatelessWidget {
  const _ListaVazia();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nenhum bairro encontrado.',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _BairroTile extends StatelessWidget {
  final String bairro;
  final List<RotaColetaModel> agendas;
  final VoidCallback onTap;

  const _BairroTile({
    required this.bairro,
    required this.agendas,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coletaHoje = agendas.any((a) => a.coletaHoje);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Flexible(
            child: Text(
              bairro,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          if (coletaHoje) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Hoje',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final a in agendas) _linhaAgenda(a)],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.hint),
    );
  }

  Widget _linhaAgenda(RotaColetaModel a) {
    final turno = a.turno == TurnoColeta.diurno ? 'diurno' : 'noturno';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 4,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: a.turno.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              '${a.descricaoDias} · $turno',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
