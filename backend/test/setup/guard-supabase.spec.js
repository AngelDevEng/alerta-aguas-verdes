const { validarHost } = require('../setup/guard-supabase');

describe('guard-supabase (whitelist de host DATABASE_URL)', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.E2E_ALLOW_DB_HOST;
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('permite host localhost', () => {
    expect(validarHost('postgres://postgres:pass@localhost:5432/db')).toBe('localhost');
  });

  it('permite host 127.0.0.1', () => {
    expect(validarHost('postgres://postgres:pass@127.0.0.1:5432/db')).toBe('127.0.0.1');
  });

  it('aborta host remoto sin opt-in', () => {
    expect(() => validarHost('postgres://user:pass@db.proveedor.com:5432/db')).toThrow('no permitido');
  });

  it('aborta host de Supabase aunque coincida con opt-in de otro host', () => {
    process.env.E2E_ALLOW_DB_HOST = 'otro.host.com';
    expect(() => validarHost('postgres://postgres:pass@rfpipjfosewqreutbyeb.supabase.co:5432/db')).toThrow('no permitido');
  });

  it('permite host exacto via E2E_ALLOW_DB_HOST', () => {
    process.env.E2E_ALLOW_DB_HOST = 'db.proveedor.com';
    expect(validarHost('postgres://user:pass@db.proveedor.com:5432/db')).toBe('db.proveedor.com');
  });

  it('aborta URL invalida', () => {
    expect(() => validarHost('no-es-url-valida')).toThrow('no es una URL valida');
  });
});
