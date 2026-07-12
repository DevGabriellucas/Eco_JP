import 'package:flutter/material.dart';

import '../models/ocorrencia_model.dart';
import '../services/ocorrencia_service.dart';
import '../theme/app_theme.dart';

enum _OcorrenciaSheetAction { edit, delete }

// ─────────────────────────────────────────
//  AÇÕES DO DONO (editar / excluir)
// ─────────────────────────────────────────

/// Abre um menu para o dono editar ou excluir a denúncia.
/// Compartilhado entre o feed (home) e o perfil.
Future<void> showOcorrenciaActions({
  required BuildContext context,
  required OcorrenciaModel ocorrencia,
  required OcorrenciaService service,
}) async {
  final action = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBDBDBD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gerenciar denúncia',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hint,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.ink,
              ),
              title: const Text('Editar título/descrição'),
              onTap: () => Navigator.pop(ctx, _OcorrenciaSheetAction.edit),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text(
                'Excluir denúncia',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, _OcorrenciaSheetAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (!context.mounted || action == null) return;

  // Aguarda o bottom sheet terminar de fechar antes de abrir o próximo
  // diálogo. Empilhar showDialog/showModalBottomSheet no mesmo ciclo do
  // Navigator dispara "Failed assertion: '_dependents.isEmpty'" (bug
  // conhecido do Flutter: https://github.com/flutter/flutter/issues/39131).
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return;

  switch (action) {
    case _OcorrenciaSheetAction.edit:
      await _editarOcorrencia(context, ocorrencia, service);
      break;
    case _OcorrenciaSheetAction.delete:
      await _confirmarExcluirOcorrencia(context, ocorrencia, service);
      break;
  }
}

Future<void> _confirmarExcluirOcorrencia(
  BuildContext context,
  OcorrenciaModel ocorrencia,
  OcorrenciaService service,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Excluir denúncia',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: const Text(
        'Tem certeza que deseja excluir esta denúncia? Esta ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.hint),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirmar == true) {
    try {
      await service.deletarOcorrencia(ocorrencia.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Denúncia excluída.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir a denúncia.')),
        );
      }
    }
  }
}

Future<void> _editarOcorrencia(
  BuildContext context,
  OcorrenciaModel ocorrencia,
  OcorrenciaService service,
) async {
  final tituloCtrl = TextEditingController(text: ocorrencia.titulo);
  final descCtrl = TextEditingController(text: ocorrencia.descricao);
  bool salvando = false;

  InputDecoration dec(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
    ),
  );

  await showDialog<void>(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Editar denúncia',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Título',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: tituloCtrl,
                    maxLength: 80,
                    decoration: dec('Título').copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Descrição',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: dec('Descrição'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: salvando ? null : () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.hint),
                ),
              ),
              ElevatedButton(
                onPressed: salvando
                    ? null
                    : () async {
                        final titulo = tituloCtrl.text.trim();
                        final desc = descCtrl.text.trim();
                        if (titulo.isEmpty || desc.isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        setDialogState(() => salvando = true);
                        try {
                          await service.atualizarTextos(
                            ocorrencia.id,
                            titulo,
                            desc,
                          );
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Denúncia atualizada.'),
                            ),
                          );
                        } catch (_) {
                          setDialogState(() => salvando = false);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Não foi possível editar.'),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );

  tituloCtrl.dispose();
  descCtrl.dispose();
}
