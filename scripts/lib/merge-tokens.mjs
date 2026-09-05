#!/usr/bin/env node
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { basename, join } from 'node:path';

const [ themeJsonPath, tokensDir ] = process.argv.slice( 2 );

if ( ! themeJsonPath || ! tokensDir ) {
	console.error( 'Usage: merge-tokens.mjs <theme.json> <tokens-dir>' );
	process.exit( 2 );
}

const readJson = ( file ) => {
	try {
		return JSON.parse( readFileSync( file, 'utf8' ) );
	} catch ( error ) {
		console.error( `Error: ${ basename( file ) } is not valid JSON — ${ error.message }` );
		process.exit( 1 );
	}
};

const isPlainObject = ( value ) =>
	value !== null && typeof value === 'object' && ! Array.isArray( value );

const deepMerge = ( target, source ) => {
	for ( const [ key, value ] of Object.entries( source ) ) {
		target[ key ] = isPlainObject( value ) && isPlainObject( target[ key ] )
			? deepMerge( target[ key ], value )
			: value;
	}
	return target;
};

const themeJson = readJson( themeJsonPath );
themeJson.settings = themeJson.settings ?? {};

for ( const file of readdirSync( tokensDir ).filter( ( f ) => f.endsWith( '.json' ) ).sort() ) {
	const settingsKey = basename( file, '.json' );
	const tokens = readJson( join( tokensDir, file ) );
	themeJson.settings[ settingsKey ] = deepMerge(
		themeJson.settings[ settingsKey ] ?? {},
		tokens
	);
}

writeFileSync( themeJsonPath, JSON.stringify( themeJson, null, '\t' ) + '\n' );
