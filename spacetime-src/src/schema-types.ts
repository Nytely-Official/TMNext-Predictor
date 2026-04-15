/**
 * Typed `ctx.db` / `tx.db` for procedure bodies (`./reducers/procedures.ts`).
 */
import type { InferSchema, ProcedureCtx, TransactionCtx } from 'spacetimedb/server';

import db from './schema';

/** Inferred from the default-exported `Schema` in `./schema.ts`. */
export type PredictorSchema = InferSchema<typeof db>;

/** Procedure (outer) context: HTTP, `withTx`, etc. */
export type PredictorProcedureCtx = ProcedureCtx<PredictorSchema>;

/** Transaction context inside `withTx`. */
export type PredictorTransactionCtx = TransactionCtx<PredictorSchema>;
