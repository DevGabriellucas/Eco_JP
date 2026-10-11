import 'package:eco_jp/models/rota_coleta_model.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Mostra a agenda de coleta de um bairro: uma ou mais frequências (turno +
/// dias da semana + horário), conforme o cronograma da Emlur. Usado tanto ao
/// tocar em uma rota no mapa quanto ao escolher um bairro na busca.
Future<void> mostrarAgendaBairroSheet(
  BuildContext context,
  String bairro,
  List<RotaColetaModel> agendas,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.pal.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AgendaBairroSheet(bairro: bairro, agendas: agendas),
  );
}

class _AgendaBairroSheet extends StatelessWidget {
  final String bairro;
  final List<RotaColetaModel> agendas;

  const _AgendaBairroSheet({required this.bairro, required this.agendas});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final temColetaHoje = agendas.any((a) => a.coletaHoje);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: pal.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.local_shipping, color: pal.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bairro,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                    ),
                  ),
                ),
                if (temColetaHoje) const _HojeBadge(),
              ],
            ),
            const SizedBox(height: 16),
            if (agendas.isEmpty)
              Text(
                'Sem informação de coleta para este bairro.',
                style: TextStyle(fontSize: 13, color: pal.muted),
              )
            else
              for (var i = 0; i < agendas.length; i++) ...[
                if (i > 0) const Divider(height: 28),
                _AgendaBlock(rota: agendas[i]),
              ],
            const SizedBox(height: 16),
            const Text(
              'Dias e turno conforme divulgado pela Emlur/Prefeitura de '
              'João Pessoa. A área marcada no mapa é aproximada — não '
              'representa a rua exata percorrida pelo caminhão. Consulte '
              'joaopessoa.pb.gov.br para o cronograma completo.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.hint,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloco de uma frequência de coleta: chip do turno, chips dos dias e horário.
class _AgendaBlock extends StatelessWidget {
  final RotaColetaModel rota;

  const _AgendaBlock({required this.rota});

  @override
  Widget build(BuildContext context) {
    final cor = rota.turno.color;
    final hoje = DateTime.now().weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(rota.turno.icon, size: 13, color: cor),
              const SizedBox(width: 4),
              Text(
                rota.turno.label,
                style: TextStyle(
                  color: cor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var dia = 1; dia <= 7; dia++) ...[
              _DiaChip(
                label: diasSemanaAbrev[dia],
                ativo: rota.diasSemana.contains(dia),
                destaque: dia == hoje,
                cor: cor,
              ),
              if (dia < 7) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.schedule, size: 16, color: context.pal.primary),
            const SizedBox(width: 6),
            Text(
              rota.horario,
              style: TextStyle(fontSize: 14, color: context.pal.ink),
            ),
          ],
        ),
      ],
    );
  }
}

class _HojeBadge extends StatelessWidget {
  const _HojeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Hoje',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DiaChip extends StatelessWidget {
  final String label;
  final bool ativo;
  final bool destaque;
  final Color cor;

  const _DiaChip({
    required this.label,
    required this.ativo,
    required this.destaque,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.15) : pal.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: destaque ? Border.all(color: cor, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w400,
            color: ativo ? cor : pal.hint,
          ),
        ),
      ),
    );
  }
}
