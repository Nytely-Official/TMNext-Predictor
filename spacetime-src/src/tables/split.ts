import { table, t } from 'spacetimedb/server';

/**
 * One finished run: cumulative checkpoint times in ms, total time, optional wall-clock `runDate`.
 * **`id`** is auto-increment; the host assigns it on `insert`.
 */
export const split = table(
	{ name: 'split', public: false },
	{
		id: t.u64().primaryKey().autoInc(),
		accountId: t.string(),
		mapUid: t.string(),
		checkpointTimes: t.array(t.u32()),
		totalTime: t.u32(),
		runDate: t.timestamp(),
	},
);
