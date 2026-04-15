import { t } from 'spacetimedb/server';

import db from '../schema';

/** Optional cleanup after the Node client has read `api_read_response`. */
export const delete_read_response = db.reducer({ requestId: t.string() }, (ctx, { requestId }) => {
	if (ctx.db.apiReadResponse.requestId.find(requestId)) {
		ctx.db.apiReadResponse.requestId.delete(requestId);
	}
});
