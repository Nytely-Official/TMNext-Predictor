import { spawnSync } from 'node:child_process';

const databaseName = process.env.SPACETIME_DATABASE ?? 'tmnext-predictor';

const result = spawnSync(
	'spacetime',
	['publish', databaseName, '-p', 'spacetime-src', '--server', 'maincloud', '-y'],
	{ stdio: 'inherit', shell: true },
);

process.exit(result.status ?? 1);
