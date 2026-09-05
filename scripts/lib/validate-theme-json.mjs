#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const [ path ] = process.argv.slice( 2 );
const fail = ( message ) => {
	console.error( `Invalid theme.json: ${ message }` );
	process.exit( 1 );
};

if ( ! path ) {
	console.error( 'Usage: validate-theme-json.mjs <path>' );
	process.exit( 2 );
}

let theme;
try {
	theme = JSON.parse( readFileSync( path, 'utf8' ) );
} catch ( error ) {
	fail( `not valid JSON — ${ error.message }` );
}

if ( theme.version !== 3 ) {
	fail( `version must be 3, found ${ JSON.stringify( theme.version ) }` );
}

for ( const key of [ 'settings', 'styles' ] ) {
	if ( key in theme && ( theme[ key ] === null || typeof theme[ key ] !== 'object' || Array.isArray( theme[ key ] ) ) ) {
		fail( `"${ key }" must be an object` );
	}
}

const palette = theme.settings?.color?.palette;
if ( palette !== undefined ) {
	if ( ! Array.isArray( palette ) ) {
		fail( 'settings.color.palette must be an array' );
	}
	const seen = new Set();
	for ( const entry of palette ) {
		for ( const field of [ 'slug', 'name', 'color' ] ) {
			if ( ! entry?.[ field ] ) {
				fail( `palette entry "${ entry?.slug ?? '(no slug)' }" is missing "${ field }"` );
			}
		}
		if ( seen.has( entry.slug ) ) {
			fail( `duplicate palette slug "${ entry.slug }"` );
		}
		seen.add( entry.slug );
	}
}

const fontSizes = theme.settings?.typography?.fontSizes;
if ( fontSizes !== undefined && ! Array.isArray( fontSizes ) ) {
	fail( 'settings.typography.fontSizes must be an array' );
}

process.exit( 0 );
