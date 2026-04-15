/**
 * Barrel for split DTOs, `submit_split` reducer, and read **procedure** bodies for `../index.ts`.
 */
export { splitDto, toSplitDto, type SplitRow } from './dto';
export { submit_split } from './submit-split.reducer';
export {
	get_global_best_for_map_procedure,
	get_personal_best_for_map_procedure,
	list_splits_for_player_map_procedure,
} from './procedures';
