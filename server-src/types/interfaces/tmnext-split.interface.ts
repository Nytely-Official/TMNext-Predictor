/**
 * Split row shape used by the HTTP API (SpacetimeDB-backed).
 */
export interface TMNextSplit {
	/**
	 * The cumulative checkpoint times in milliseconds
	 */
	checkpointTimes: number[];

	/**
	 * The final finish time in milliseconds
	 */
	totalTime: number;

	/**
	 * The date of the run
	 */
	runDate: Date;
}
