/**
 * Re-exports all **table schema handles** for the predictor module.
 *
 * The object passed to `schema()` must use the same keys (`player`, `trackMap`, `split`) as in
 * `../schema-types.ts` so `tx.db` typing stays aligned.
 */
export { player } from './player';
export { trackMap } from './track-map';
export { split } from './split';
