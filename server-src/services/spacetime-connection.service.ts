/**
 * Singleton **WebSocket client** to SpacetimeDB for the Fastify API.
 *
 * Environment:
 * - **`SPACETIME_URI`** — WebSocket URL (default `wss://maincloud.spacetimedb.com`).
 * - **`SPACETIME_DATABASE`** — Published database name (default `tmnext-predictor`; must match `spacetime publish`).
 * - **`SPACETIME_TOKEN`** — Optional auth token from a prior `onConnect` (omit for anonymous local dev).
 */
import type { ErrorContext } from '../spacetime-bindings';
import { DbConnection } from '../spacetime-bindings';
import type { Identity } from 'spacetimedb';

const SPACETIME_URI = process.env.SPACETIME_URI ?? 'wss://maincloud.spacetimedb.com';
const SPACETIME_DATABASE = process.env.SPACETIME_DATABASE ?? 'tmnext-predictor';
const SPACETIME_TOKEN = process.env.SPACETIME_TOKEN;

let connection: DbConnection | null = null;
let connectPromise: Promise<DbConnection> | null = null;

/**
 * Returns a shared, connected {@link DbConnection}. Concurrent callers await the same in-flight connect.
 */
export function getSpacetimeConnection(): Promise<DbConnection> {
	if (connection) return Promise.resolve(connection);
	if (connectPromise) return connectPromise;

	connectPromise = new Promise<DbConnection>((resolve, reject) => {
		DbConnection.builder()
			.withUri(SPACETIME_URI)
			.withDatabaseName(SPACETIME_DATABASE)
			.withToken(SPACETIME_TOKEN)
			.onConnect((conn: DbConnection, _identity: Identity, _token: string) => {
				connection = conn;
				resolve(conn);
			})
			.onConnectError((ctx: ErrorContext, err: Error) => {
				console.error('SpacetimeDB connect error:', err);
				reject(err);
			})
			.build();
	});

	return connectPromise;
}

/** Closes the client and allows a future {@link getSpacetimeConnection} to reconnect. */
export async function disconnectSpacetime(): Promise<void> {
	if (connection) {
		connection.disconnect();
		connection = null;
	}
	connectPromise = null;
}
