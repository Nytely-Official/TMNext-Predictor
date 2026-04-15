/**
 * Re-exports all **table schema handles** for the predictor module.
 *
 * The object passed to `schema()` in `../schema.ts` must use the same keys (`player`, `trackMap`, `split`)
 * so `tx.db` typing stays aligned with `../schema-types.ts`.
 */
export { apiReadResponse } from './api-read-response';
export { player } from './player';
export { trackMap } from './track-map';
export { split } from './split';
