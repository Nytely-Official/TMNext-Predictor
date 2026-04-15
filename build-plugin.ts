//Imports
import { homedir } from 'os';
import { cpSync, existsSync } from 'fs';
import { resolve } from 'path';
import { zip } from 'zip-a-folder';
import { rimraf } from 'rimraf';

/**
 * Optional override: set in `.env` (Bun loads it when you `bun run build-plugin.ts`).
 * Path to the Openplanet **Plugins** directory (absolute, or relative to the project root).
 */
const OPENPLANET_PLUGINS_PATH_ENV = 'OPENPLANET_PLUGINS_PATH';

function getDefaultOpenplanetPluginsDirectory(): string {
	return `${homedir()}/openplanetnext/Plugins`;
}

function resolveOpenplanetPluginsDirectory(): string {
	const defaultPath = getDefaultOpenplanetPluginsDirectory();
	const fromEnv = process.env[OPENPLANET_PLUGINS_PATH_ENV]?.trim();
	if (fromEnv) return resolve(process.cwd(), fromEnv);
	return defaultPath;
}

//Log Start of Build
console.log('-=+=- Building the Plugin');

//Constants
const openplanetPluginsDirectory = resolveOpenplanetPluginsDirectory();
const sourceDirectory = `${process.cwd()}/plugin-src`;

//Check if the Openplanet Plugins Folder does not exist
if (!existsSync(openplanetPluginsDirectory)) throw new Error(`Can not Find Openplanet Plugins at -- ${openplanetPluginsDirectory}`);

// Delete the Old Plugin using rimraf
await rimraf(`${openplanetPluginsDirectory}/PredictorDev`);

//Copy over the Dev Plugin to the Openplanet Plugins Folder
cpSync(`${sourceDirectory}`, `${openplanetPluginsDirectory}/PredictorDev`, { recursive: true });

//Zip the Contents of the Source Directory to the Releases Directory
zip(sourceDirectory, `${process.cwd()}/Releases/Predictor.op`);

//Log Successful Build
console.log(
	`
	\n-=+=- Plugin Built Successfully to -- ${openplanetPluginsDirectory}/Predictor-DEV.op
	\n-=+=- Plugin Built Successfully to -- ${process.cwd()}/Releases/Predictor.op
	`,
);
