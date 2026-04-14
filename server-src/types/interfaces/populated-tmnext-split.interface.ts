import { TMNextSplit } from './tmnext-split.interface';

/**
 * Split with string identifiers for player and map (Openplanet account id and map uid).
 */
export interface PopulatedTMNextSplit extends TMNextSplit {
	/**
	 * Split row id (SpacetimeDB auto-increment as string)
	 */
	id: string;

	/**
	 * Trackmania / Openplanet account id
	 */
	playerId: string;

	/**
	 * Map uid
	 */
	mapId: string;
}
