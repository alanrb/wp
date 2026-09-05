#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';

const [ command, manifestPath, pattern, source, rev, checksum ] = process.argv.slice( 2 );

const load = () => {
	try {
		const data = JSON.parse( readFileSync( manifestPath, 'utf8' ) );
		data.patterns = data.patterns ?? {};
		return data;
	} catch {
		return { patterns: {} };
	}
};

if ( command === 'read' ) {
	process.stdout.write( load().patterns[ pattern ]?.checksum ?? '' );
} else if ( command === 'write' ) {
	const data = load();
	data.patterns[ pattern ] = { source, rev, checksum };
	writeFileSync( manifestPath, JSON.stringify( data, null, '\t' ) + '\n' );
} else {
	console.error( 'Usage: manifest.mjs read|write <manifest> <pattern> [source] [rev] [checksum]' );
	process.exit( 2 );
}
