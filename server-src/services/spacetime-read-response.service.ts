import { randomUUID } from 'node:crypto';

import type { DbConnection } from '../spacetime-bindings';

const pending = new Map<string, (payload: string) => void>();

let hookInstalled = false;

/**
 * Registers a one-time `onInsert` handler so read reducers can deliver JSON via `api_read_response`.
 * Must run after {@link DbConnection} is created; call once per process.
 */
export function ensureReadResponseHook(conn: DbConnection): void {
	if (hookInstalled) return;
	hookInstalled = true;
	conn.db.apiReadResponse.onInsert((_ctx, row) => {
		const resolve = pending.get(row.requestId);
		if (resolve) {
			pending.delete(row.requestId);
			resolve(row.payloadJson);
		}
	});
}

export function newReadRequestId(): string {
	return randomUUID();
}

export function waitForReadPayload(requestId: string, timeoutMs: number): Promise<string> {
	return new Promise((resolve, reject) => {
		const timer = setTimeout(() => {
			pending.delete(requestId);
			reject(new Error('Timed out waiting for read reducer (api_read_response)'));
		}, timeoutMs);
		pending.set(requestId, payload => {
			clearTimeout(timer);
			resolve(payload);
		});
	});
}
