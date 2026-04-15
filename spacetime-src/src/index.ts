/**
 * TMNext Predictor — **reducers only**. Reads return data by inserting JSON into `api_read_response`
 * (`public: true`) so the Node client can `subscribe` + `onInsert` (reducers cannot return values in TS).
 */
import db from './schema';

export {
	delete_read_response,
	get_global_best_for_map,
	get_personal_best_for_map,
	list_splits_for_player_map,
	submit_split,
} from './reducers';

export default db;
