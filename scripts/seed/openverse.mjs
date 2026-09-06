#!/usr/bin/env node
/**
 * Find an openly-licensed image for a search term via Openverse.
 *
 * Prefers CC0 / public-domain marks so a delivered client site carries no
 * attribution obligation; falls back to CC-BY and reports the credit that must
 * then be shown. Prints one tab-separated row:
 *
 *   <image url>\t<title>\t<creator>\t<license>\t<source page>
 *
 * Usage: openverse.mjs "<query>" [index]
 */

const [ query, indexArg ] = process.argv.slice( 2 );
const index = Number( indexArg || 0 );

if ( ! query ) {
	console.error( 'Usage: openverse.mjs "<query>" [index]' );
	process.exit( 2 );
}

const search = async ( licenses ) => {
	const url =
		'https://api.openverse.org/v1/images/?' +
		new URLSearchParams( {
			q: query,
			license: licenses,
			page_size: '20',
			mature: 'false',
		} );

	const response = await fetch( url, { headers: { Accept: 'application/json' } } );

	if ( ! response.ok ) {
		throw new Error( `Openverse returned ${ response.status } for "${ query }"` );
	}

	const data = await response.json();
	return ( data.results ?? [] ).filter( ( r ) => r.url && ! r.url.endsWith( '.svg' ) );
};

let results = await search( 'cc0,pdm' );
let attributionRequired = false;

if ( results.length <= index ) {
	results = await search( 'by,by-sa' );
	attributionRequired = true;
}

if ( results.length === 0 ) {
	console.error( `No openly-licensed image found for "${ query }"` );
	process.exit( 1 );
}

const pick = results[ index % results.length ];

process.stdout.write(
	[
		pick.url,
		( pick.title ?? query ).replace( /\s+/g, ' ' ).trim(),
		pick.creator ?? '',
		`${ pick.license }${ pick.license_version ? ' ' + pick.license_version : '' }${
			attributionRequired ? ' (attribution required)' : ''
		}`,
		pick.foreign_landing_url ?? '',
	].join( '\t' ) + '\n'
);
