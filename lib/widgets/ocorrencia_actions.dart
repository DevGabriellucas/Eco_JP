import 'package:flutter/material.dart';

import '../data/repositories/ocorrencia_repository.dart';
import '../models/ocorrencia_model.dart';
import '../theme/app_theme.dart';
import '../utils/mensagem_erro.dart';

enum _OcorrenciaSheetAction { edit, delete }

// ─────────────────────────────────────────
//  AÇÕES DO DONO (editar / excluir)
// ─────────────────────────────────────────

/// Abre um menu para o dono editar ou excluir a denúncia.
/// Compartilhado entre o feed (home) e o perfil.
Future<void> showOcorrenciaActions({
  required BuildContext context,
  required OcorrenciaModel ocorrencia,
  required OcorrenciaRepository service,
}) async {
  final action = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: context.pal.surface,
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
                color: context.pal.border,
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
            // Depois que a autoridade agiu (verificou ou mudou o status), o
            // texto fica travado: o selo "Verificada por <órgão>" atestaria
            // um conteúdo que o órgão nunca viu. As regras também negam.
            if (podeEditarTextos(ocorrencia))
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: context.pal.ink,
                ),
                title: const Text('Editar título/descrição'),
                onTap: () => Navigator.pop(ctx, _OcorrenciaSheetAction.edit),
              )
            else
              const ListTile(
                enabled: false,
                leading: Icon(Icons.edit_off_outlined),
                title: Text('Editar título/descrição'),
                subtitle: Text('Já analisada pela autoridade'),
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
  OcorrenciaRepository service,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.pal.surface,
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro(e, acao: 'excluir a denúncia'))),
        );
      }
    }
  }
}

Future<void> _editarOcorrencia(
  BuildContext context,
  OcorrenciaModel ocorrencia,
  OcorrenciaRepository service,
) async {
  final tituloCtrl = TextEditingController(text: ocorrencia.titulo);
  final descCtrl = TextEditingController(text: ocorrencia.descricao);
  bool salvando = false;

  InputDecoration dec(String hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.pal.ink, width: 1.5),
        ),
      );

  await showDialog<void>(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: context.pal.surface,
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
                    maxLength: 1000,
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
                        final messenger = ScaffoldMessenger.of(context);
                        // Mesmos limites das regras (isValidTitle /
                        // isValidDescription); fora deles a gravação era
                        // negada com um "Não foi possível editar." genérico.
                        final problema = titulo.length < 3
                            ? 'O título precisa de pelo menos 3 caracteres.'
                            : titulo.length > 80
                                ? 'O título pode ter no máximo 80 caracteres.'
                                : desc.length < 10
                                    ? 'A descrição precisa de pelo menos 10 caracteres.'
                                    : desc.length > 1000
                                        ? 'A descrição pode ter no máximo 1000 caracteres.'
                                        : null;
                        if (problema != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(problema)),
                          );
                          return;
                        }
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
                  backgroundColor: context.pal.ink,
                  foregroundColor: context.pal.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: salvando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.pal.surface,
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

  // O diálogo ainda reconstrói os TextFields durante a animação de saída;
  // descartar os controllers na hora gerava "used after being disposed".
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    tituloCtrl.dispose();
    descCtrl.dispose();
  });
}

/// Se o dono ainda pode editar título/descrição: só antes de a autoridade
/// verificar ou definir um status oficial (espelha a regra de update).
bool podeEditarTextos(OcorrenciaModel o) =>
    !o.verificada && o.statusOficial == null;
