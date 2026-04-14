// External Imports
import { FastifyInstance, FastifyReply } from 'fastify';

// Internal Imports
import { getGlobalBestSplit, getPlayerBestSplit, getPlayerSplits, saveSplit } from '../services/split.service';
import { authenticateRequest } from '../middleware/auth.middleware';
import {
	GetSplitsType,
	PopulatedTMNextSplit,
	type AuthenticatedRequest,
	type GetSplitsRequest,
	type SaveSplitRequest,
} from '../types/types';

/**
 * Register the Split Routes
 * @param fastify The Fastify Instance
 * @returns void
 */
export async function registerSplitRoutes(fastify: FastifyInstance): Promise<void> {
	// Save a new split
	fastify.post('/splits/save', { preHandler: authenticateRequest }, (request: AuthenticatedRequest, reply: FastifyReply) =>
		saveSplitHandler(request as SaveSplitRequest, reply),
	);

	// Handles Split Fetching
	fastify.post('/splits/get', { preHandler: authenticateRequest }, (request: AuthenticatedRequest, reply: FastifyReply) =>
		getSplitsHandler(request as GetSplitsRequest, reply),
	);
}

/**
 * Split Handler
 * @param request The authenticated request
 * @param reply The Fastify reply
 * @returns The response
 */
async function saveSplitHandler(request: SaveSplitRequest, reply: FastifyReply) {
	// Get the user ID and display name
	const userId = request.userId!;
	const displayName = request.displayName!;

	// Get the map ID, checkpoint times, total time and run date from the body
	const { mapId, checkpointTimes, totalTime, runDate } = request.body;

	// Check if the Map ID Is missing
	if (!mapId) return reply.code(400).send({ error: 'mapId is required' });

	// Check if the Checkpoint Times Is missing
	if (!checkpointTimes) return reply.code(400).send({ error: 'checkpointTimes is required' });

	// Check if the Total Time Is missing
	if (!totalTime) return reply.code(400).send({ error: 'totalTime is required' });

	// Check if the Checkpoint Times Is not an array
	if (!Array.isArray(checkpointTimes) || checkpointTimes.length === 0)
		return reply.code(400).send({ error: 'checkpointTimes must be a non-empty array' });

	// Check if the Total Time Is not a number or is not positive
	if (typeof totalTime !== 'number' || totalTime <= 0) return reply.code(400).send({ error: 'totalTime must be a positive number' });

	// Save the split
	const split = await saveSplit(userId, displayName, mapId, {
		checkpointTimes,
		totalTime,
		runDate: runDate ? new Date(runDate) : null,
	}).catch(error => {
		// Log the error
		console.error('Error saving split:', error);

		// Setup the new Error Response
		const errorResponse = new Error('Failed to save split');

		// Return the error response
		return errorResponse;
	});

	// Check if the Split is a type of Error and return the error response
	if (split instanceof Error) return reply.code(500).send({ error: split.message });

	// Setup the Response Data
	const responseData = {
		id: split.id,
		mapId,
		checkpointTimes: split.checkpointTimes,
		totalTime: split.totalTime,
		runDate: split.runDate,
	};

	// Return the response
	return reply.code(201).send({ success: true, data: responseData });
}

/**
 * Get Splits Handler
 * @param request The authenticated request
 * @param reply The Fastify reply
 * @returns The response
 */
async function getSplitsHandler(request: GetSplitsRequest, reply: FastifyReply) {
	// Get the user ID and display name
	const userId = request.userId!;

	// Get the map ID, checkpoint times, total time and run date from the body
	const { mapId, type } = request.body;

	// Check if the Map ID Is missing
	if (!mapId) return reply.code(400).send({ error: 'mapId is required' });

	// Check if the Type Is missing
	if (!type) return reply.code(400).send({ error: 'type is required' });

	// Setup the Splits Array
	const splits: Array<PopulatedTMNextSplit> = new Array();

	// Log the user ID and map ID
	console.log('User ID:', userId);
	console.log('Map ID:', mapId);
	console.log('Type:', type);

	// Check if the Type Is All
	if (type === GetSplitsType.ALL) {
		// Get the player splits
		const playerSplits = await getPlayerSplits(userId, mapId);

		// Check if the Player Splits Is not null and add it to the splits array
		if (playerSplits) splits.push(...playerSplits);
	}

	// Check if the Type Is Global Best
	if (type === GetSplitsType.GLOBAL_BEST) {
		// Get the global best split
		const globalBestSplit = await getGlobalBestSplit(mapId);

		// Check if the Global Best Split Is not null and add it to the splits array
		if (globalBestSplit) splits.push(globalBestSplit);
	}

	// Check if the Type Is Personal Best
	if (type === GetSplitsType.PERSONAL_BEST) {
		// Get the personal best split
		const personalBestSplit = await getPlayerBestSplit(userId, mapId);

		// Check if the Personal Best Split Is not null and add it to the splits array
		if (personalBestSplit) splits.push(personalBestSplit);
	}

	// Map the Splits to a proper response format
	const mappedSplits = splits.map(split => ({
		id: split.id,
		playerId: split.playerId,
		mapId: split.mapId,
		checkpointTimes: split.checkpointTimes,
		totalTime: split.totalTime,
		runDate: split.runDate,
	}));

	// Setup the Response Data
	const data = { success: true, data: mappedSplits };

	// Log the response data
	console.log('Data:', data);

	// Return the response
	return reply.code(200).send(data);
}
