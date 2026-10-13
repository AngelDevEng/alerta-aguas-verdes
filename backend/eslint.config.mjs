import js from '@eslint/js';
import tseslint from 'typescript-eslint';

// Config pragmática: valida errores reales sin imponer estilo que el codebase
// actual (heredado) no sigue. Las reglas de estilo se pueden endurecer después.
export default tseslint.config(
  { ignores: ['dist/**', 'node_modules/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      // TS ya cubre identificadores; no-undef genera falsos positivos aquí.
      'no-undef': 'off',
      // El acceso a la BD usa `any` en params de TypeORM.query de forma deliberada.
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/no-require-imports': 'off',
      'no-empty': 'off',
    },
  },
);
