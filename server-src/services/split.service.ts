import { Timestamp } from 'spacetimedb';

import { getSpacetimeConnection } from './spacetime-connection.service';
import { newReadRequestId, waitForReadPayload } from './spacetime-read-response.service';
import type { Split } from '../spacetime-bindings/types.ts';
import type { PopulatedTMNextSplit, SaveSplitData } from '../types/types';

/** Wire shape emitted by module `wireSplitDto` / list JSON. */
type WireSplit = {
	splitId: string;
	accountId: string;
	displayName: string;
	mapUid: string;
	checkpointTimes: number[];
	totalTime: number;
	runDateMicros: string;
};

function wireToSplit(w: WireSplit): Split {
	return {
		id: BigInt(w.splitId),
		accountId: w.accountId,
		mapUid: w.mapUid,
		checkpointTimes: w.checkpointTimes,
		totalTime: w.totalTime,
		runDate: new Timestamp(BigInt(w.runDateMicros)),
	};
}

function splitToPopulated(d: Split): PopulatedTMNextSplit {
	return {
		id: d.id.toString(),
		playerId: d.accountId,
		mapId: d.mapUid,
		checkpointTimes: d.checkpointTimes,
		totalTime: d.totalTime,
		runDate: d.runDate.toDate(),
	};
}

const READ_TIMEOUT_MS = 20_000;

async function readJsonViaReducer(
	invoke: (requestId: string) => Promise<void>,
): Promise<string> {
	const conn = await getSpacetimeConnection();
	const requestId = newReadRequestId();
	const payloadPromise = waitForReadPayload(requestId, READ_TIMEOUT_MS);
	await invoke(requestId);
	const json = await payloadPromise;
	await conn.reducers.deleteReadResponse({ requestId }).catch(() => {});
	return json;
}

/**
 * Saves a run via `submit_split`, then loads the newest row via `list_splits_for_player_map` reducer + staging table.
 */
export async function saveSplit(
	accountId: string,
	displayName: string,
	mapId: string,
	splitData: SaveSplitData,
): Promise<PopulatedTMNextSplit> {
	const conn = await getSpacetimeConnection();

	const runDate =
		splitData.runDate != null ? Timestamp.fromDate(splitData.runDate) : undefined;

	await conn.reducers.submitSplit({
		accountId,
		displayName,
		mapUid: mapId,
		checkpointTimes: splitData.checkpointTimes,
		totalTime: splitData.totalTime,
		runDate,
	});

	const json = await readJsonViaReducer(requestId =>
		conn.reducers.listSplitsForPlayerMap({ accountId, mapUid: mapId, requestId }),
	);

	const rows = JSON.parse(json) as WireSplit[];
	if (!Array.isArray(rows) || rows.length === 0) {
		throw new Error('submit_split completed but list_splits_for_player_map returned no rows');
	}

	let newest = wireToSplit(rows[0]!);
	for (const w of rows.slice(1)) {
		const d = wireToSplit(w);
		if (d.id > newest.id) newest = d;
	}

	return splitToPopulated(newest);
}

/** All splits for the player on the map (reducer `list_splits_for_player_map`). */
export async function getPlayerSplits(accountId: string, mapId: string): Promise<Array<PopulatedTMNextSplit>> {
	const conn = await getSpacetimeConnection();
	const json = await readJsonViaReducer(requestId =>
		conn.reducers.listSplitsForPlayerMap({ accountId, mapUid: mapId, requestId }),
	);
	const rows = JSON.parse(json) as WireSplit[];
	if (!Array.isArray(rows)) return [];
	return rows.map(w => splitToPopulated(wireToSplit(w)));
}

/** Personal best (reducer `get_personal_best_for_map`). */
export async function getPlayerBestSplit(accountId: string, mapId: string): Promise<PopulatedTMNextSplit | null> {
	const conn = await getSpacetimeConnection();
	const json = await readJsonViaReducer(requestId =>
		conn.reducers.getPersonalBestForMap({ accountId, mapUid: mapId, requestId }),
	);
	if (json === 'null') return null;
	const w = JSON.parse(json) as WireSplit;
	return splitToPopulated(wireToSplit(w));
}

/** Global best (reducer `get_global_best_for_map`). */
export async function getGlobalBestSplit(mapId: string): Promise<PopulatedTMNextSplit | null> {
	const conn = await getSpacetimeConnection();
	const json = await readJsonViaReducer(requestId => conn.reducers.getGlobalBestForMap({ mapUid: mapId, requestId }));
	if (json === 'null') return null;
	const w = JSON.parse(json) as WireSplit;
	return splitToPopulated(wireToSplit(w));
}
