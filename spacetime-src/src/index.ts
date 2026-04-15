/**
 * TMNext Predictor — SpacetimeDB v2 TypeScript module.
 *
 * **SpacetimeDB distinguishes reducers vs procedures** (see official docs: Reducers, Procedures):
 *
 * - **`db.reducer`** — Only way to **mutate** tables; the function returns **`void`**. Use for writes (`submit_split`).
 * - **`db.procedure` + `ctx.withTx`** — The supported way to run **read transactions that return values** to the
 *   caller. This is **not SQL**: each export is one named remote function on the same `/call` path as reducers.
 *
 * You cannot implement “get split and return DTO” as a reducer in TypeScript (reducers are `void`). Reads that
 * must return data are therefore **procedures**, which is how SpacetimeDB v2 is designed.
 *
 * Run `bun run generate` from the repo root after changing signatures.
 */
import { t } from 'spacetimedb/server';

import db from './schema';
import {
	get_global_best_for_map_procedure,
	get_personal_best_for_map_procedure,
	list_splits_for_player_map_procedure,
	splitDto,
} from './reducers';

export { submit_split } from './reducers/submit-split.reducer';

export default db;

/** All splits for a player on a map (sorted by total time ascending). */
export const list_splits_for_player_map = db.procedure(
	{ accountId: t.string(), mapUid: t.string() },
	t.array(splitDto),
	list_splits_for_player_map_procedure,
);

/** Fastest split for that player on that map, or `undefined` if none. */
export const get_personal_best_for_map = db.procedure(
	{ accountId: t.string(), mapUid: t.string() },
	t.option(splitDto),
	get_personal_best_for_map_procedure,
);

/** Fastest split on the map across players, or `undefined` if none. */
export const get_global_best_for_map = db.procedure(
	{ mapUid: t.string() },
	t.option(splitDto),
	get_global_best_for_map_procedure,
);
