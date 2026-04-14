/**
 * Player record fields exposed in API responses (Trackmania account id).
 */
export interface TMNextPlayer {
	/**
	 * The player's account ID from Openplanet / Trackmania.
	 */
	accountId: string;

	/**
	 * The player's current display name.
	 */
	displayName: string;
}