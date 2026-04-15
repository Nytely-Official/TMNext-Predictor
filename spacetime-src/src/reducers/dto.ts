/**
 * Shared **algebraic types** for procedure parameters and return values.
 *
 * `splitDto` mirrors the shape returned to the Fastify server after `spacetime generate`.
 */
import type { Timestamp } from 'spacetimedb';
import { t } from 'spacetimedb/server';

/** Wire / client shape for a split row returned by read procedures (and after `submit_split`). */
export const splitDto = t.object('SplitDto', {
	splitId: t.u64(),
	accountId: t.string(),
	displayName: t.string(),
	mapUid: t.string(),
	checkpointTimes: t.array(t.u32()),
	totalTime: t.u32(),
	runDate: t.timestamp(),
});

/**
 * Narrow view of a `split` table row used when mapping `iter()` results to {@link splitDto}.
 * Matches the `split` table columns in `../tables/split.ts`.
 */
export type SplitRow = {
	id: bigint;
	accountId: string;
	mapUid: string;
	checkpointTimes: number[];
	totalTime: number;
	runDate: Timestamp;
};

/**
 * Builds a {@link splitDto} value from a stored row plus the player’s display name (denormalized for clients).
 */
export function toSplitDto(row: SplitRow, displayName: string) {
	return {
		splitId: row.id,
		accountId: row.accountId,
		displayName,
		mapUid: row.mapUid,
		checkpointTimes: row.checkpointTimes,
		totalTime: row.totalTime,
		runDate: row.runDate,
	};
}
