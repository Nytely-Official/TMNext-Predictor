/**
 * Persists a finished run (mutation only). Reads stay as `db.procedure` in `../index.ts`.
 */
import { SenderError } from 'spacetimedb/server';
import { t } from 'spacetimedb/server';

import db from '../schema';

export const submit_split = db.reducer(
	{
		accountId: t.string(),
		displayName: t.string(),
		mapUid: t.string(),
		checkpointTimes: t.array(t.u32()),
		totalTime: t.u32(),
		runDate: t.option(t.timestamp()),
	},
	(ctx, args) => {
		const { accountId, displayName, mapUid, checkpointTimes, totalTime, runDate } = args;
		if (checkpointTimes.length === 0) throw new SenderError('checkpointTimes must be non-empty');
		if (totalTime <= 0) throw new SenderError('totalTime must be positive');

		const existingPlayer = ctx.db.player.accountId.find(accountId);
		if (!existingPlayer) {
			ctx.db.player.insert({ accountId, displayName });
		} else if (existingPlayer.displayName !== displayName) {
			ctx.db.player.accountId.update({ accountId, displayName });
		}

		if (!ctx.db.trackMap.mapUid.find(mapUid)) {
			ctx.db.trackMap.insert({ mapUid });
		}

		const when = runDate !== undefined ? runDate : ctx.timestamp;

		ctx.db.split.insert({
			accountId,
			mapUid,
			checkpointTimes,
			totalTime,
			runDate: when,
		} as never);
	},
);
