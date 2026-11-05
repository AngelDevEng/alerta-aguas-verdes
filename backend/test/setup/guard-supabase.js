module.exports = async () => {
  const url = process.env.DATABASE_URL || '';
  if (url.toLowerCase().includes('supabase')) {
    throw new Error('test:e2e abortado: DATABASE_URL apunta a Supabase; usar base local.');
  }
};
