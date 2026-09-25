import 'package:flutter/material.dart';

import '../../models/occurrence_types.dart';
import '../../models/ocorrencia_model.dart';
import '../../theme/app_theme.dart';
import '../shared/app_icons.dart';

class HomeOverview extends StatelessWidget {
  final List<OcorrenciaModel> occurrences;
  final OccurrenceType? selectedType;
  final ValueChanged<OccurrenceType?> onSelectType;
  final VoidCallback onCreateOccurrence;
  final VoidCallback onOpenMap;

  const HomeOverview(
      {super.key,
      required this.occurrences,
      required this.selectedType,
      required this.onSelectType,
      required this.onCreateOccurrence,
      required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    final resolved = occurrences
        .where((o) => o.statusOficial == StatusOficial.resolvida)
        .length;
    final active = occurrences.length - resolved;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _HeroBanner(onTap: onCreateOccurrence),
      const SizedBox(height: 12),
      _Categories(selected: selectedType, onSelected: onSelectType),
      const SizedBox(height: 12),
      _Metrics(total: occurrences.length, resolved: resolved, active: active),
      const SizedBox(height: 14),
      _SatellitePreview(occurrences: occurrences, onTap: onOpenMap),
      const SizedBox(height: 16),
    ]);
  }
}

class _HeroBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          height: 166,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/feed/reference_hero.png',
                fit: BoxFit.cover),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: MediaQuery.sizeOf(context).width * .58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF024B35).withValues(alpha: .96),
                    const Color(0xFF024B35).withValues(alpha: .72),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            const Positioned(
              left: 17,
              top: 15,
              child: SizedBox(
                width: 210,
                child: Text(
                  'Cidades mais verdes\ncomeçam com pessoas\ncomo você.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.02,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const Positioned(
              left: 17,
              top: 82,
              child: Text('Denuncie. Acompanhe. Transforme.',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
            Positioned(
              left: 17,
              bottom: 13,
              child: SizedBox(
                height: 35,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE9FFF4),
                      foregroundColor: const Color(0xFF075E43),
                      padding: const EdgeInsets.fromLTRB(13, 0, 7, 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Fazer uma denúncia',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    SizedBox(width: 7),
                    CircleAvatar(
                        radius: 11,
                        backgroundColor: Color(0xFF087653),
                        child: Icon(Icons.arrow_forward,
                            color: Colors.white, size: 13)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _CategoryOption {
  final String label;
  final IconData icon;
  final OccurrenceType? type;
  const _CategoryOption(this.label, this.icon, this.type);
}

class _Categories extends StatelessWidget {
  final OccurrenceType? selected;
  final ValueChanged<OccurrenceType?> onSelected;
  const _Categories({required this.selected, required this.onSelected});

  static const options = [
    _CategoryOption('Todos', Icons.grid_view_rounded, null),
    _CategoryOption(
        'Desmatamento', Icons.park_rounded, OccurrenceType.arvoresCaidas),
    _CategoryOption('Poluição', Icons.factory_rounded, OccurrenceType.queimada),
    _CategoryOption('Resíduos', Icons.recycling_rounded, OccurrenceType.lixo),
    _CategoryOption('Água', Icons.water_drop_rounded, OccurrenceType.enchentes),
    _CategoryOption('Fauna', Icons.pets_rounded, OccurrenceType.outros),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 82,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final option = options[index];
            final selectedOption = selected == option.type;
            return InkWell(
              onTap: () => onSelected(option.type),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
                decoration: BoxDecoration(
                    color:
                        selectedOption ? const Color(0xFF006D4D) : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFE9EFEC))),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(option.icon,
                          size: 23,
                          color: selectedOption
                              ? Colors.white
                              : const Color(0xFF17324A)),
                      const SizedBox(height: 7),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(option.label,
                              style: TextStyle(
                                  color: selectedOption
                                      ? Colors.white
                                      : const Color(0xFF17324A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600))),
                    ]),
              ),
            );
          },
        ),
      );
}

class _Metrics extends StatelessWidget {
  final int total;
  final int resolved;
  final int active;
  const _Metrics(
      {required this.total, required this.resolved, required this.active});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _MetricCard(
                icon: Icons.eco_rounded, value: total, label: 'Denúncias')),
        const SizedBox(width: 8),
        Expanded(
            child: _MetricCard(
                icon: Icons.check_rounded,
                value: resolved,
                label: 'Resolvidas')),
        const SizedBox(width: 8),
        Expanded(
            child: _MetricCard(
                icon: Icons.schedule_rounded,
                value: active,
                label: 'Em andamento',
                warning: true)),
      ]);
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final bool warning;
  const _MetricCard(
      {required this.icon,
      required this.value,
      required this.label,
      this.warning = false});

  @override
  Widget build(BuildContext context) {
    final accent = warning ? const Color(0xFFFFA21A) : AppColors.primary;
    return Container(
      height: 104,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFFAEC) : const Color(0xFFF0FFF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white)),
      child: Row(children: [
        CircleAvatar(
            radius: 17,
            backgroundColor: accent,
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 6),
        Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('$value',
                  style: const TextStyle(
                      color: Color(0xFF15223B),
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF536078), fontSize: 9, height: 1)),
              const SizedBox(height: 3),
              const Text('dados atuais',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w600)),
            ])),
      ]),
    );
  }
}

class _SatellitePreview extends StatelessWidget {
  final List<OcorrenciaModel> occurrences;
  final VoidCallback onTap;
  const _SatellitePreview({required this.occurrences, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final markers = occurrences
        .where((o) => o.latitude != 0 && o.longitude != 0)
        .take(8)
        .toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(
        height: 176,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/feed/reference_satellite_map.png',
              fit: BoxFit.cover),
          Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
            Color(0xF0054938),
            Color(0xB3054938),
            Colors.transparent
          ], stops: [
            0,
            .38,
            .68
          ]))),
          for (var i = 0; i < markers.length; i++)
            Positioned(
                left: 185 + ((i * 47) % 120).toDouble(),
                top: 18 + ((i * 37) % 125).toDouble(),
                child: _MapMarker(
                    type:
                        OccurrenceTypeParser.fromString(markers[i].tipoLixo))),
          const Positioned(
            left: 15,
            top: 14,
            child: SizedBox(
              width: 145,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Problemas\nambientais\nperto de você',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.03,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    SizedBox(
                        width: 140,
                        child: Text(
                            'Veja no mapa as denúncias da sua região em tempo real.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                height: 1.15))),
                  ]),
            ),
          ),
          Positioned(
            left: 15,
            bottom: 13,
            child: SizedBox(
              height: 34,
              child: FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF0FFF7),
                  foregroundColor: const Color(0xFF075E43),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                ),
                icon: const Icon(AppIcons.map, size: 16),
                label: const Text(
                  'Abrir mapa  ›',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final OccurrenceType type;
  const _MapMarker({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      OccurrenceType.enchentes ||
      OccurrenceType.esgoto =>
        const Color(0xFF269BEA),
      OccurrenceType.lixo || OccurrenceType.queimada => const Color(0xFFFF922B),
      OccurrenceType.arvoresCaidas => AppColors.primary,
      _ => const Color(0xFFE7343F),
    };
    return Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2)),
        child: Icon(type.icon, color: Colors.white, size: 13));
  }
}
