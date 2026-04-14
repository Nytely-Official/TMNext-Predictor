import { table, t } from 'spacetimedb/server';

/**
 * Trackmania map identity (`mapUid` from the game / plugin), used to scope splits.
 */
export const trackMap = table(
	{ name: 'track_map', public: false },
	{
		mapUid: t.string().primaryKey(),
	},
);
