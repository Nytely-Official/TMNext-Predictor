/**
 * Root schema: `ctx.db` / `tx.db` in procedures (matches the working `spacetimedb-module-EXAMPLE` layout).
 */
import { schema, CaseConversionPolicy } from 'spacetimedb/server';

import { player, split, trackMap } from './tables';

const db = schema(
	{ player, trackMap, split },
	{ CASE_CONVERSION_POLICY: CaseConversionPolicy.None },
);

export default db;
