/**
 * Read paths for `db.procedure` in `../index.ts` — `ctx.withTx` + table iterators / PK lookups only (no SQL).
 */
import type { PredictorProcedureCtx, PredictorTransactionCtx } from '../schema-types';
import { toSplitDto, type SplitRow } from './dto';

export function list_splits_for_player_map_procedure(
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

export function get_personal_best_for_map_procedure(
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

export function get_global_best_for_map_procedure(ctx: PredictorProcedureCtx, args: { mapUid: string }) {
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
