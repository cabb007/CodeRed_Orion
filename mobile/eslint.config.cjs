const { defineConfig } = require('eslint/config');
const expo = require('eslint-config-expo/flat');
module.exports = defineConfig([
  expo,
  { ignores: ['dist/**', '.expo/**', 'node_modules/**'] },
  { rules: { 'react-hooks/exhaustive-deps': 'off' } },
]);
