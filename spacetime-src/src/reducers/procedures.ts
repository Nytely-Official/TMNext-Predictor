/**
 * Procedure **implementations** passed to `spacetimedb.procedure(..., fn)` from `../index.ts`.
 *
 * All reads use `tx.db.*.iter()` or primary-key indexes only (no SQL). Writes run inside `withTx`.
 */
import type { Timestamp } from 'spacetimedb';
import { SenderError } from 'spacetimedb/server';

import type { PredictorProcedureCtx, PredictorTransactionCtx } from '../schema-types';
import { toSplitDto, type SplitRow } from './dto';

/** Arguments for {@link submitSplitProcedure} — `runDate` matches SpacetimeDB’s `t.option(t.timestamp())` inference. */
export type SubmitSplitProcedureArgs = {
	accountId: string;
	displayName: string;
	mapUid: string;
	checkpointTimes: number[];
	totalTime: number;
	/** Present when the client sent a run time; otherwise the module uses `tx.timestamp`. */
	runDate: Timestamp | undefined;
};

/**
 * Persists a finished run: upsert player and map rows, insert split, return a {@link SplitDto}.
 */
export function submitSplitProcedure(ctx: PredictorProcedureCtx, args: SubmitSplitProcedureArgs) {
	return ctx.withTx((tx: PredictorTransactionCtx) => {
		const { accountId, displayName, mapUid, checkpointTimes, totalTime, runDate } = args;
		if (checkpointTimes.length === 0) throw new SenderError('checkpointTimes must be non-empty');
		if (totalTime <= 0) throw new SenderError('totalTime must be positive');

		const existingPlayer = tx.db.player.accountId.find(accountId);
		if (!existingPlayer) {
			tx.db.player.insert({ accountId, displayName });
		} else if (existingPlayer.displayName !== displayName) {
			tx.db.player.accountId.update({ accountId, displayName });
		}

		if (!tx.db.trackMap.mapUid.find(mapUid)) {
			tx.db.trackMap.insert({ mapUid });
		}

		const when = runDate !== undefined ? runDate : tx.timestamp;

		// `insert` typings include auto-increment `id` even though the host fills it at runtime.
		const inserted = tx.db.split.insert({
			accountId,
			mapUid,
			checkpointTimes,
			totalTime,
			runDate: when,
		} as never);

		const p = tx.db.player.accountId.find(inserted.accountId);
		return toSplitDto(inserted as SplitRow, p?.displayName ?? '');
	});
}

/**
 * Lists every split for `(accountId, mapUid)` and sorts by `totalTime` ascending (same ordering as the old Mongo query).
 */
export function listSplitsForPlayerMapProcedure(
	ctx: PredictorProcedureCtx,
	args: { accountId: string; mapUid: string },
) {
	const { accountId, mapUid } = args;
	return ctx.withTx((tx: PredictorTransactionCtx) => {
		const out: ReturnType<typeof toSplitDto>[] = [];
		for (const row of tx.db.split.iter()) {
			if (row.accountId !== accountId || row.mapUid !== mapUid) continue;
			const p = tx.db.player.accountId.find(row.accountId);
			const name = p?.displayName ?? '';
			out.push(toSplitDto(row as SplitRow, name));
		}
		out.sort((a, b) => Number(a.totalTime - b.totalTime));
		return out;
	});
}

/**
 * Lowest `totalTime` for the player on the map, or `undefined` if no rows (SpacetimeDB option as `T | undefined` in TS).
 */
export function getPersonalBestForMapProcedure(
	ctx: PredictorProcedureCtx,
	args: { accountId: string; mapUid: string },
) {
	const { accountId, mapUid } = args;
	return ctx.withTx((tx: PredictorTransactionCtx) => {
		let best: SplitRow | null = null;
		for (const row of tx.db.split.iter()) {
			if (row.accountId !== accountId || row.mapUid !== mapUid) continue;
			if (!best || row.totalTime < best.totalTime) best = row as SplitRow;
		}
		if (!best) return undefined;
		const p = tx.db.player.accountId.find(best.accountId);
		return toSplitDto(best, p?.displayName ?? '');
	});
}

/**
 * Lowest `totalTime` on the map for any player, or `undefined` if no rows.
 */
export function getGlobalBestForMapProcedure(ctx: PredictorProcedureCtx, args: { mapUid: string }) {
	const { mapUid } = args;
	return ctx.withTx((tx: PredictorTransactionCtx) => {
		let best: SplitRow | null = null;
		for (const row of tx.db.split.iter()) {
			if (row.mapUid !== mapUid) continue;
			if (!best || row.totalTime < best.totalTime) best = row as SplitRow;
		}
		if (!best) return undefined;
		const p = tx.db.player.accountId.find(best.accountId);
		return toSplitDto(best, p?.displayName ?? '');
	});
}
