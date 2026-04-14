/**
 * Central place for the predictor module’s **schema-level TypeScript types**.
 *
 * `TablesToSchema` is not re-exported from `spacetimedb/server`, so we import it from the
 * installed package’s `dist` typings (keep `spacetimedb` in `spacetime-src/package.json` aligned with
 * the CLI). Supplying `ProcedureCtx<PredictorSchema>` / `TransactionCtx<PredictorSchema>` unlocks
 * typed `tx.db.*` and PK index helpers (e.g. `tx.db.player.accountId.find`).
 */
import type { TablesToSchema } from '../../node_modules/spacetimedb/dist/lib/schema';
import type { ProcedureCtx, TransactionCtx } from 'spacetimedb/server';

import { player, trackMap, split } from './tables';

/**
 * Table handles keyed exactly as in `schema({ ... })` in `index.ts`.
 * Keep this object in sync with the default export’s `schema()` argument.
 */
export const predictorTables = {
	player,
	trackMap,
	split,
} as const;

/** Inferred schema definition used by SpacetimeDB for `ctx.db` / `tx.db`. */
export type PredictorSchema = TablesToSchema<typeof predictorTables>;

/** Procedure (outer) context: HTTP, `withTx`, etc. */
export type PredictorProcedureCtx = ProcedureCtx<PredictorSchema>;

/** Reducer / transaction context: full `db` with typed tables and indexes. */
export type PredictorTransactionCtx = TransactionCtx<PredictorSchema>;
