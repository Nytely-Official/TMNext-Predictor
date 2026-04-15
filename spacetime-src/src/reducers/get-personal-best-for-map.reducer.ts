import { t } from 'spacetimedb/server';

import db from '../schema';
import { toSplitDto, type SplitRow } from './dto';
import { wireSplitDto } from './split-wire';

export const get_personal_best_for_map = db.reducer(
	{ accountId: t.string(), mapUid: t.string(), requestId: t.string() },
	(ctx, { accountId, mapUid, requestId }) => {
		let best: SplitRow | null = null;
		for (const row of ctx.db.split.iter()) {
			if (row.accountId !== accountId || row.mapUid !== mapUid) continue;
			if (!best || row.totalTime < best.totalTime) best = row as SplitRow;
		}
		const payload =
			best == null
				? 'null'
				: wireSplitDto(toSplitDto(best, ctx.db.player.accountId.find(best.accountId)?.displayName ?? ''));

		ctx.db.apiReadResponse.insert({
			requestId,
			payloadJson: payload,
			createdAt: ctx.timestamp,
		} as never);
	},
);
