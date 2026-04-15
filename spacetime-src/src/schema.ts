/**
 * Root schema: `ctx.db` in reducers (plus public `api_read_response` for read staging).
 */
import { schema, CaseConversionPolicy } from 'spacetimedb/server';

import { apiReadResponse, player, split, trackMap } from './tables';

const db = schema(
	{ apiReadResponse, player, trackMap, split },
	{ CASE_CONVERSION_POLICY: CaseConversionPolicy.None },
);

export default db;
