/**
 * Barrel for **procedure bodies** and DTO helpers consumed by `../index.ts`.
 *
 * SpacetimeDB calls these units “reducers” in docs generically; this project only uses **procedures**
 * for reads/writes that return data to the Node/Bun API.
 */
export { splitDto, toSplitDto, type SplitRow } from './dto';
export {
	getGlobalBestForMapProcedure,
	getPersonalBestForMapProcedure,
	listSplitsForPlayerMapProcedure,
	submitSplitProcedure,
	type SubmitSplitProcedureArgs,
} from './procedures';
