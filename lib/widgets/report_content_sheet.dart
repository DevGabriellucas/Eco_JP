import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReportContentResult {
  final String motivo;
  final String? detalhe;

  const ReportContentResult({required this.motivo, this.detalhe});
}

Future<ReportContentResult?> showReportContentSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<ReportContentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.pal.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ReportContentSheet(title: title),
  );
}

class _ReportContentSheet extends StatefulWidget {
  final String title;

  const _ReportContentSheet({required this.title});

  @override
  State<_ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<_ReportContentSheet> {
  static const _motivos = [
    'Informação falsa',
    'Spam',
    'Conteúdo ofensivo',
    'Imagem inadequada',
    'Outro motivo',
  ];

  final TextEditingController _detalheCtrl = TextEditingController();
  String _motivo = _motivos.first;

  @override
  void dispose() {
    _detalheCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      ReportContentResult(
        motivo: _motivo,
        detalhe: _detalheCtrl.text.trim().isEmpty
            ? null
            : _detalheCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: pal.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: TextStyle(
              color: pal.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._motivos.map(
            (motivo) => InkWell(
              onTap: () => setState(() => _motivo = motivo),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _SelectionDot(selected: _motivo == motivo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        motivo,
                        style: TextStyle(
                          fontSize: 14,
                          color: pal.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _detalheCtrl,
            maxLines: 3,
            maxLength: 240,
            style: TextStyle(color: pal.ink),
            decoration: InputDecoration(
              hintText: 'Detalhe opcional',
              hintStyle: TextStyle(color: pal.hint),
              filled: true,
              fillColor: pal.surfaceAlt,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Enviar denúncia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  final bool selected;

  const _SelectionDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.danger : context.pal.hint,
          width: selected ? 6 : 2,
        ),
      ),
    );
  }
}
