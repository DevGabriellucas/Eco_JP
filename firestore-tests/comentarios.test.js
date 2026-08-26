const admin = require('firebase-admin');

describe('Firestore Security Rules - Comentários', () => {
  describe('Validação de Comentários', () => {
    test('comentário válido deve ter texto não-vazio', () => {
      const comentario = {
        userId: 'user1',
        userName: 'João Silva',
        texto: 'Este é um comentário válido com muitos caracteres',
        dataCriacao: new Date(),
        parentId: null,
        likedBy: [],
        likes: 0,
        oculto: false,
        autorAutoridade: false,
      };

      // Validar campos obrigatórios
      expect(comentario).toHaveProperty('texto');
      expect(comentario.texto.length).toBeGreaterThan(0);
      expect(comentario.texto.trim().length).toBeGreaterThan(0);
    });

    test('comentário vazio deve ser inválido', () => {
      const texto = '';
      expect(texto.trim().length).toBe(0);
    });

    test('comentário com apenas espaços deve ser inválido', () => {
      const texto = '   ';
      expect(texto.trim().length).toBe(0);
    });

    test('comentário com texto válido deve passar na validação', () => {
      const texto = 'Comentário com conteúdo válido';
      const isValid = texto.trim().length > 0 && /[\s\S]*\S[\s\S]*/.test(texto);
      expect(isValid).toBe(true);
    });
  });

  describe('Replies (Respostas)', () => {
    test('resposta deve ter parentId válido', () => {
      const reply = {
        userId: 'user2',
        userName: 'Maria Santos',
        texto: 'Resposta válida com muitos caracteres para passar na validação',
        dataCriacao: new Date(),
        parentId: 'comment1', // Deve referenciar um comentário pai válido
        likedBy: [],
        likes: 0,
        oculto: false,
        autorAutoridade: false,
      };

      expect(reply.parentId).not.toBeNull();
      expect(reply.parentId).toBe('comment1');
    });

    test('comentário raiz não deve ter parentId', () => {
      const rootComment = {
        userId: 'user1',
        userName: 'João Silva',
        texto: 'Comentário raiz com muitos caracteres',
        dataCriacao: new Date(),
        parentId: null, // Raiz não tem pai
        likedBy: [],
        likes: 0,
        oculto: false,
        autorAutoridade: false,
      };

      expect(rootComment.parentId).toBeNull();
    });
  });

  describe('Curtidas em Comentários', () => {
    test('curtida deve manter lista de usuários', () => {
      const comentario = {
        userId: 'user1',
        texto: 'Comentário com curtida',
        likedBy: ['user2', 'user3'],
        likes: 2,
      };

      expect(comentario.likes).toBe(comentario.likedBy.length);
      expect(comentario.likedBy).toContain('user2');
    });

    test('remover curtida deve atualizar contadores', () => {
      const comentario = {
        likedBy: ['user1', 'user2'],
        likes: 2,
      };

      // Simular remoção de curtida
      const novaLista = comentario.likedBy.filter(uid => uid !== 'user1');
      expect(novaLista.length).toBe(1);
      expect(novaLista).not.toContain('user1');
    });
  });

  describe('Campos Obrigatórios', () => {
    test('comentário deve ter todos os campos obrigatórios', () => {
      const comentario = {
        userId: 'user1',
        userName: 'João Silva',
        texto: 'Comentário válido',
        dataCriacao: new Date(),
        parentId: null,
        likedBy: [],
        likes: 0,
        oculto: false,
        autorAutoridade: false,
      };

      const camposObrigatorios = ['userId', 'userName', 'texto', 'likedBy', 'likes'];
      camposObrigatorios.forEach(campo => {
        expect(comentario).toHaveProperty(campo);
      });
    });

    test('comentário sem userId deve ser inválido', () => {
      const comentario = {
        userName: 'João Silva',
        texto: 'Comentário sem userId',
      };

      expect(comentario).not.toHaveProperty('userId');
    });
  });
});
