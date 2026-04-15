import { spawnSync } from 'node:child_process';

const databaseName = process.env.SPACETIME_DATABASE ?? 'tmnext-predictor';

const build = spawnSync('spacetime', ['build', '-p', 'spacetime-src'], { stdio: 'inherit', shell: true });
if (build.status !== 0) process.exit(build.status ?? 1);

const result = spawnSync(
	'spacetime',
	['publish', databaseName, '-p', 'spacetime-src', '--server', 'maincloud', '-y'],
	{ stdio: 'inherit', shell: true },
);

process.exit(result.status ?? 1);
