/**
 * Anpheros Platform client.
 *
 * ```ts
 * const anpheros = new Anpheros({ auth: apiKey('sk_test_…') });
 * const { data } = await anpheros.patients.list();
 * const labs = await anpheros.observations.list(data[0].id, { category: 'laboratory' });
 * ```
 */
export * from './client.js';
export * from './auth.js';
export * from './errors.js';
export * from './models.js';
export * from './oauth.js';
export * from './webhooks.js';
