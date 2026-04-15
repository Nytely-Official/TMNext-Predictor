import { table, t } from 'spacetimedb/server';

/**
 * Staging rows so **read reducers** (which return `void`) can deliver JSON payloads to the Node API via
 * `conn.db.apiReadResponse.onInsert` after `subscribe`.
 */
export const apiReadResponse = table(
	{ name: 'api_read_response', public: true },
	{
		requestId: t.string().primaryKey(),
		payloadJson: t.string(),
		createdAt: t.timestamp(),
	},
);
