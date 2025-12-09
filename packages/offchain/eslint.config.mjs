import eslint from '@eslint/js';
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';
import vitestEslint from '@vitest/eslint-plugin';

export default defineConfig(
  {
    ignores: ['**/dist/*', '**/node_modules/*'],
  },
  {
    files: ['**/*.ts'],
    extends: [
      // The vitest eslint recommended is important at least because it's easy to forget `expect`'s matcher calls.
      vitestEslint.configs.recommended,
      eslint.configs.recommended,
      tseslint.configs.recommendedTypeChecked,
      {
        languageOptions: {
          parserOptions: {
            projectService: true,
            tsconfigRootDir: import.meta.dirname,
          },
        },
      },
    ],
    rules: {
      'vitest/expect-expect': 'off',
      'no-unreachable': 'warn',
      'no-use-before-define': 'error',
      'no-unused-expressions': 'warn',
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          args: 'all',
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          caughtErrorsIgnorePattern: '^_',
        },
      ],
    },
  },
);
