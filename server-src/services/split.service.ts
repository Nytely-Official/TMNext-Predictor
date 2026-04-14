import { Timestamp } from 'spacetimedb';

import { getSpacetimeConnection } from './spacetime-connection.service';
import type { SplitDto } from '../spacetime-bindings/types.ts';
import type { PopulatedTMNextSplit, SaveSplitData } from '../types/types';

/**
 * Maps a SpacetimeDB {@link SplitDto} (procedure return shape) into the Fastify route DTO.
 */
function splitDtoToPopulated(d: SplitDto): PopulatedTMNextSplit {
	return {
		id: d.splitId.toString(),
		playerId: d.accountId,
		mapId: d.mapUid,
		checkpointTimes: d.checkpointTimes,
		totalTime: d.totalTime,
		runDate: d.runDate.toDate(),
	};
}

/**
 * Saves a finished run via the `submitSplit` procedure (no SQL on the API side).
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

	const dto = await conn.procedures.submitSplit({
		accountId,
		displayName,
		mapUid: mapId,
		checkpointTimes: splitData.checkpointTimes,
		totalTime: splitData.totalTime,
		runDate,
	});

	return splitDtoToPopulated(dto);
}

/** All splits for the player on the map, sorted by total time (ascending). */
export async function getPlayerSplits(accountId: string, mapId: string): Promise<Array<PopulatedTMNextSplit>> {
	const conn = await getSpacetimeConnection();
	const rows = await conn.procedures.listSplitsForPlayerMap({ accountId, mapUid: mapId });
	return rows.map(splitDtoToPopulated);
}

/** Personal best for the map, or `null` if none (procedure uses optional return). */
export async function getPlayerBestSplit(accountId: string, mapId: string): Promise<PopulatedTMNextSplit | null> {
	const conn = await getSpacetimeConnection();
	const best = await conn.procedures.getPersonalBestForMap({ accountId, mapUid: mapId });
	return best != null ? splitDtoToPopulated(best) : null;
}

/** Global best on the map, or `null` if none. */
export async function getGlobalBestSplit(mapId: string): Promise<PopulatedTMNextSplit | null> {
	const conn = await getSpacetimeConnection();
	const best = await conn.procedures.getGlobalBestForMap({ mapUid: mapId });
	return best != null ? splitDtoToPopulated(best) : null;
}
