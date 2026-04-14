/**
 * TMNext Predictor — SpacetimeDB **module entry**.
 *
 * - **Default export**: schema instance (required by the SpacetimeDB host).
 * - **Named exports**: procedures the Fastify API calls via generated client bindings.
 *
 * Table definitions live under `./tables/`. Procedure implementations live under `./reducers/`.
 * Run `bun run generate:spacetime` from the repo root after changing tables or procedure signatures.
 */
import { schema, t, CaseConversionPolicy } from 'spacetimedb/server';

import { predictorTables } from './schema-types';
import {
	getGlobalBestForMapProcedure,
	getPersonalBestForMapProcedure,
	listSplitsForPlayerMapProcedure,
	splitDto,
	submitSplitProcedure,
} from './reducers';

const spacetimedb = schema(predictorTables, {
	CASE_CONVERSION_POLICY: CaseConversionPolicy.None,
});

export default spacetimedb;

/** Inserts a finished run; returns the new row as {@link splitDto}. */
export const submitSplit = spacetimedb.procedure(
	{
		accountId: t.string(),
		displayName: t.string(),
		mapUid: t.string(),
		checkpointTimes: t.array(t.u32()),
		totalTime: t.u32(),
		runDate: t.option(t.timestamp()),
	},
	splitDto,
	submitSplitProcedure,
);

/** All splits for a player on a map, ordered by finish time (ascending). */
export const listSplitsForPlayerMap = spacetimedb.procedure(
	{ accountId: t.string(), mapUid: t.string() },
	t.array(splitDto),
	listSplitsForPlayerMapProcedure,
);

/** Fastest split for that player on that map, or `undefined` if none. */
export const getPersonalBestForMap = spacetimedb.procedure(
	{ accountId: t.string(), mapUid: t.string() },
	t.option(splitDto),
	getPersonalBestForMapProcedure,
);

/** Fastest split on the map across all players, or `undefined` if none. */
export const getGlobalBestForMap = spacetimedb.procedure(
	{ mapUid: t.string() },
	t.option(splitDto),
	getGlobalBestForMapProcedure,
);
