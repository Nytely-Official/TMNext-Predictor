import { t } from 'spacetimedb/server';

import db from '../schema';
import { toSplitDto, type SplitRow } from './dto';
import { wireSplitDto } from './split-wire';

export const list_splits_for_player_map = db.reducer(
	{ accountId: t.string(), mapUid: t.string(), requestId: t.string() },
	(ctx, { accountId, mapUid, requestId }) => {
		const out: ReturnType<typeof toSplitDto>[] = [];
		for (const row of ctx.db.split.iter()) {
			if (row.accountId !== accountId || row.mapUid !== mapUid) continue;
			const p = ctx.db.player.accountId.find(row.accountId)?.displayName ?? '';
			out.push(toSplitDto(row as SplitRow, p));
		}
		out.sort((a, b) => Number(a.totalTime - b.totalTime));
		const payload = '[' + out.map(d => wireSplitDto(d)).join(',') + ']';

		ctx.db.apiReadResponse.insert({
			requestId,
			payloadJson: payload,
			createdAt: ctx.timestamp,
		} as never);
	},
);
