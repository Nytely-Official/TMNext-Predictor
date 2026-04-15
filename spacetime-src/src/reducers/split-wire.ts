/**
 * JSON payloads written to `api_read_response` for the Node client to parse (reducers cannot return values).
 */
import type { SplitRow } from './dto';
import { toSplitDto } from './dto';

export function wireSplitDto(d: ReturnType<typeof toSplitDto>): string {
	return JSON.stringify({
		splitId: d.splitId.toString(),
		accountId: d.accountId,
		displayName: d.displayName,
		mapUid: d.mapUid,
		checkpointTimes: d.checkpointTimes,
		totalTime: d.totalTime,
		runDateMicros: d.runDate.microsSinceUnixEpoch.toString(),
	});
}

/** `list_splits_for_player_map` — JSON array of wire objects. */
export function buildListSplitsJson(
	getRow: (accountId: string, mapUid: string) => Iterable<SplitRow>,
	getDisplayName: (accountId: string) => string,
	accountId: string,
	mapUid: string,
): string {
	const out: ReturnType<typeof toSplitDto>[] = [];
	for (const row of getRow(accountId, mapUid)) {
		const p = getDisplayName(row.accountId);
		out.push(toSplitDto(row, p));
	}
	out.sort((a, b) => Number(a.totalTime - b.totalTime));
	return JSON.stringify(out.map(wireSplitDto));
}
