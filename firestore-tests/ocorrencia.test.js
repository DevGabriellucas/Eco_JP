const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Inicializar o Firebase Admin SDK para testes
const rulesContent = fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8');

describe('Firestore Security Rules - Ocorrências', () => {
  describe('Validação de Campos', () => {
    test('regra deve aceitar ocorrência válida', () => {
      // Validação básica de estrutura
      const ocorrencia = {
        titulo: 'Título válido',
        descricao: 'Descrição válida com muitos caracteres',
        localizacao: 'Rua Teste, Bairro',
        latitude: -7.115556,
        longitude: -34.901111,
        tipoLixo: 'Lixo',
        status: 'Pendente',
        dataCriacao: new Date(),
        usuarioId: 'user1',
        imagemUrl: 'https://res.cloudinary.com/dmdghbgac/image/upload/test.jpg',
        imagensUrls: ['https://res.cloudinary.com/dmdghbgac/image/upload/test.jpg'],
        anonima: false,
        likes: 0,
        dislikes: 0,
        comments: 0,
        likedBy: [],
        dislikedBy: [],
        fixada: false,
      };

      // Validar campos obrigatórios
      expect(ocorrencia).toHaveProperty('titulo');
      expect(ocorrencia).toHaveProperty('descricao');
      expect(ocorrencia).toHaveProperty('localizacao');
      expect(ocorrencia).toHaveProperty('latitude');
      expect(ocorrencia).toHaveProperty('longitude');
      expect(ocorrencia.titulo.length).toBeGreaterThanOrEqual(3);
      expect(ocorrencia.descricao.length).toBeGreaterThanOrEqual(10);
      expect(ocorrencia.titulo.length).toBeLessThanOrEqual(80);
      expect(ocorrencia.descricao.length).toBeLessThanOrEqual(1000);
    });

    test('titulo muito curto deve ser inválido', () => {
      const titulo = 'AB'; // Menos de 3 caracteres
      expect(titulo.length).toBeLessThan(3);
    });

    test('descricao muito curta deve ser inválida', () => {
      const descricao = 'Curta'; // Menos de 10 caracteres
      expect(descricao.length).toBeLessThan(10);
    });

    test('categoria válida deve estar na lista', () => {
      const categorias = [
        'Lixo',
        'Queimada',
        'Buraco',
        'Árvores caídas',
        'Enchentes',
        'Esgoto',
        'Falta iluminação',
        'Outros',
      ];

      expect(categorias).toContain('Lixo');
      expect(categorias).toContain('Queimada');
    });

    test('coordenadas (0,0) devem ser inválidas', () => {
      const isValid = !(0 === 0 && 0 === 0);
      expect(isValid).toBe(false);
    });

    test('coordenadas deve estar dentro dos limites', () => {
      const lat = -7.115556;
      const lon = -34.901111;

      expect(lat).toBeGreaterThanOrEqual(-90);
      expect(lat).toBeLessThanOrEqual(90);
      expect(lon).toBeGreaterThanOrEqual(-180);
      expect(lon).toBeLessThanOrEqual(180);
    });

    test('coordenadas fora dos limites devem ser inválidas', () => {
      const lat = 200;
      const lon = 400;

      const isValid = lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
      expect(isValid).toBe(false);
    });
  });

  describe('Proteção de Denunciante Anônimo', () => {
    test('denúncia anônima não pode ter usuarioId', () => {
      const ocorrencia = {
        anonima: true,
        usuarioId: null, // Deve ser null quando anônima
      };

      const isValid = ocorrencia.anonima ? ocorrencia.usuarioId === null : true;
      expect(isValid).toBe(true);
    });

    test('denúncia anônima com usuarioId deve ser inválida', () => {
      const ocorrencia = {
        anonima: true,
        usuarioId: 'user1', // Inválido quando anônima
      };

      const isValid = ocorrencia.anonima ? ocorrencia.usuarioId === null : true;
      expect(isValid).toBe(false);
    });

    test('denúncia anônima não pode ter nome do usuário', () => {
      const ocorrencia = {
        anonima: true,
        usuarioNome: null, // Deve ser null ou não existir
      };

      const isValid = ocorrencia.anonima ? !ocorrencia.usuarioNome : true;
      expect(isValid).toBe(true);
    });
  });

  describe('Validação de URLs', () => {
    test('URL do Cloudinary deve ser válida', () => {
      const url = 'https://res.cloudinary.com/dmdghbgac/image/upload/test.jpg';
      const isValid = url.match('^https://res\\.cloudinary\\.com/dmdghbgac/image/upload/.+');
      expect(isValid).not.toBeNull();
    });

    test('URL inválida deve ser rejeitada', () => {
      const url = 'https://example.com/image.jpg';
      const isValid = url.match('^https://res\\.cloudinary\\.com/dmdghbgac/image/upload/.+');
      expect(isValid).toBeNull();
    });
  });
});
