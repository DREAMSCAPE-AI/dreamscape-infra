/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>'],
  testMatch: ['**/__tests__/**/*.test.js'],
  collectCoverageFrom: [
    'middleware/**/*.js',
    'config/**/*.js',
    'server.js'
  ],
  coverageDirectory: 'coverage',
  verbose: false,
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js']
};
