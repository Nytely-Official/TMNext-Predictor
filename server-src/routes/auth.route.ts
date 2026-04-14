// External Imports
import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { sign } from 'jsonwebtoken';

// Internal Imports
import { AuthenticationPayload, AuthUserResponse, AuthValidationResponse, type AuthUserRequest } from '../types/types';

// Get the Environment Variables
const JWT_SECRET = process.env.JWT_SECRET;
const OPENPLANET_SECRET = process.env.OPENPLANET_SECRET;
const OPENPLANET_VALIDATION_URL = process.env.OPENPLANET_VALIDATION_URL || 'https://api.openplanet.dev/auth/validate';

/**
 * Register the Auth Routes
 * @param fastify The Fastify Instance
 * @returns void
 */
export async function registerAuthRoutes(fastify: FastifyInstance) {
	// Authenticate the User
	fastify.post('/auth', (request: FastifyRequest, reply: FastifyReply) => authenticateUser(request as unknown as AuthUserRequest, reply));
}

/**
 * Authenticate the User
 * @param request The Auth User Request
 * @param reply The Fastify Reply
 * @returns void
 */
export async function authenticateUser(request: AuthUserRequest, reply: FastifyReply): Promise<void> {
	// If the Openplanet Secret is not configured, return an error
	if (!OPENPLANET_SECRET || !JWT_SECRET) return reply.code(500).send({ error: 'Server authentication not configured' });

	// Get the Openplanet Token from the request body
	const token = request.body?.openplanetToken;

	// If the token is not present, return an error
	if (!token) return reply.code(401).send({ error: 'Missing body parameter: openplanetToken' });

	// Setup the URL Encoded Form Data
	const urlEncodedData = new URLSearchParams();
	urlEncodedData.append('token', token);
	urlEncodedData.append('secret', OPENPLANET_SECRET);

	// Setup the Request Options
	const requestOptions: RequestInit = {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: urlEncodedData.toString(),
	};

	// Validate token with Openplanet
	const response = await fetch(OPENPLANET_VALIDATION_URL, requestOptions).catch(error => {
		// Log the Error
		console.error('Error validating token:', error);

		// Create the Error Response
		const errorResponse = new Error('Authentication failed');

		// Return the Error Message
		return errorResponse;
	});

	// Check if the Response is an Error
	if (response instanceof Error) return reply.code(500).send({ error: 'Authentication failed' });

	// Parse the Response as JSON
	const data: AuthValidationResponse = await response.json();

	// If there is an error, return an error
	if (data.error) return reply.code(401).send({ error: data.error });

	// If the account ID or display name is not present, return an error
	if (!data.account_id || !data.display_name) return reply.code(401).send({ error: 'Invalid authentication response' });

	// Setup the JWT Payload
	const payload: AuthenticationPayload = {
		accountId: data.account_id,
		displayName: data.display_name,
		tokenTime: data.token_time || 0,
	};

	// Sign the JWT Payload
	const signedToken = sign(payload, JWT_SECRET);

	// Setup the Response Data
	const responseData: AuthUserResponse = {
		token: signedToken,
	};

	// Return the Response
	return reply.code(200).send({ success: true, data: responseData });
}
