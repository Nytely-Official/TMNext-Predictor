import { table, t } from 'spacetimedb/server';

/**
 * Openplanet / Trackmania player keyed by stable **`accountId`** (primary key).
 * `displayName` is refreshed whenever a client submits a split.
 */
export const player = table(
	{ name: 'player', public: false },
	{
		accountId: t.string().primaryKey(),
		displayName: t.string(),
	},
);
