import { spawnSync } from 'node:child_process';

const databaseName = process.env.SPACETIME_DATABASE ?? 'tmnext-predictor';

/** Extra flags, e.g. `--break-clients` if maincloud refuses to add procedures to an existing DB. Space-separated. */
const extraPublishArgs = (process.env.SPACETIME_EXTRA_PUBLISH_FLAGS ?? '')
	.trim()
	.split(/\s+/)
	.filter(Boolean);

const build = spawnSync('spacetime', ['build', '-p', 'spacetime-src'], { stdio: 'inherit', shell: true });
if (build.status !== 0) process.exit(build.status ?? 1);

const result = spawnSync(
	'spacetime',
	['publish', databaseName, '-p', 'spacetime-src', '--server', 'maincloud', '-y', ...extraPublishArgs],
	{ stdio: 'inherit', shell: true },
);

process.exit(result.status ?? 1);
