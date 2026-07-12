import 'package:flutter/material.dart';

import '../models/ocorrencia_model.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';

/// Snapshot do estado de reação de uma ocorrência, usado para reverter uma
/// atualização otimista se a gravação no servidor falhar.
class ReacaoSnapshot {
  final bool userLiked;
  final bool userDisliked;
  final int likes;
  final int dislikes;
  final List<String> likedBy;
  final List<String> dislikedBy;

  ReacaoSnapshot({
    required this.userLiked,
    required this.userDisliked,
    required this.likes,
    required this.dislikes,
    required this.likedBy,
    required this.dislikedBy,
  });

  factory ReacaoSnapshot.de(OcorrenciaModel o) => ReacaoSnapshot(
    userLiked: o.userLiked,
    userDisliked: o.userDisliked,
    likes: o.likes,
    dislikes: o.dislikes,
    likedBy: List<String>.from(o.likedBy),
    dislikedBy: List<String>.from(o.dislikedBy),
  );

  void restaurarEm(OcorrenciaModel o) {
    o.userLiked = userLiked;
    o.userDisliked = userDisliked;
    o.likes = likes;
    o.dislikes = dislikes;
    o.likedBy = likedBy;
    o.dislikedBy = dislikedBy;
  }
}

/// Aplica o toggle de like de forma otimista em [o] (mutação em memória).
/// Regra: like e dislike são mutuamente exclusivos; clicar de novo desfaz.
void aplicarLikeOtimista(OcorrenciaModel o, String uid) {
  if (o.userLiked) {
    o.userLiked = false;
    o.likes--;
    o.likedBy.remove(uid);
  } else {
    if (o.userDisliked) {
      o.userDisliked = false;
      o.dislikes--;
      o.dislikedBy.remove(uid);
    }
    o.userLiked = true;
    o.likes++;
    if (!o.likedBy.contains(uid)) o.likedBy.add(uid);
  }
}

/// Aplica o toggle de dislike de forma otimista em [o] (mutação em memória).
void aplicarDislikeOtimista(OcorrenciaModel o, String uid) {
  if (o.userDisliked) {
    o.userDisliked = false;
    o.dislikes--;
    o.dislikedBy.remove(uid);
  } else {
    if (o.userLiked) {
      o.userLiked = false;
      o.likes--;
      o.likedBy.remove(uid);
    }
    o.userDisliked = true;
    o.dislikes++;
    if (!o.dislikedBy.contains(uid)) o.dislikedBy.add(uid);
  }
}

/// Executa o fluxo completo de curtir/descurtir uma ocorrência: aplica a
/// mudança otimista, grava no servidor, reverte em caso de erro (mostrando
/// aviso), e notifica o dono quando aplicável. Usado tanto pelo feed quanto
/// pela tela de detalhe — antes cada uma reimplementava esse algoritmo à
/// parte, e podiam divergir silenciosamente.
Future<void> reagirOcorrencia({
  required BuildContext context,
  required OcorrenciaModel ocorrencia,
  required String uid,
  required bool isLike,
  required OcorrenciaService ocorrenciaService,
  required NotificacaoService notificacaoService,
  required String? nomeAutor,
  required VoidCallback onMudou,
}) async {
  final vaiCurtir = isLike && !ocorrencia.userLiked;
  final anterior = ReacaoSnapshot.de(ocorrencia);

  onMudouComEstado() {
    if (isLike) {
      aplicarLikeOtimista(ocorrencia, uid);
    } else {
      aplicarDislikeOtimista(ocorrencia, uid);
    }
    onMudou();
  }

  onMudouComEstado();

  try {
    if (isLike) {
      await ocorrenciaService.toggleLike(ocorrencia.id, uid);
    } else {
      await ocorrenciaService.toggleDislike(ocorrencia.id, uid);
    }
  } catch (_) {
    anterior.restaurarEm(ocorrencia);
    onMudou();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isLike
              ? 'Não foi possível curtir agora. Tente novamente.'
              : 'Não foi possível reagir agora. Tente novamente.',
        ),
      ),
    );
    return;
  }

  // Denúncia anônima nunca notifica o dono (S2): o UID real não é acessível
  // a quem curte, protegendo o denunciante de correlação entre denúncias.
  final dono = ocorrencia.usuarioId;
  if (vaiCurtir && !ocorrencia.anonima && dono != null && dono != uid) {
    notificacaoService.notificar(
      donoId: dono,
      tipo: 'curtida',
      deUsuarioNome: nomeAutor ?? 'Alguém',
      ocorrenciaId: ocorrencia.id,
      ocorrenciaTitulo: ocorrencia.titulo,
    );
  }
}
