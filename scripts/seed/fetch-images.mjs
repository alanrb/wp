#!/usr/bin/env node
/**
 * Resolve an openly-licensed image for each seed term and print a JSON map.
 *
 * Usage: fetch-images.mjs term:query [term:query ...]
 */

const args = process.argv.slice( 2 );

const search = async ( query, licenses ) => {
	const url =
		'https://api.openverse.org/v1/images/?' +
		new URLSearchParams( { q: query, license: licenses, page_size: '20', mature: 'false' } );
	const response = await fetch( url, { headers: { Accept: 'application/json' } } );
	if ( ! response.ok ) {
		return [];
	}
	const data = await response.json();
	return ( data.results ?? [] ).filter(
		( r ) => r.url && /\.(jpe?g|png)$/i.test( r.url ) && ( r.width ?? 0 ) >= 600
	);
};

const out = {};

for ( const arg of args ) {
	const separator = arg.indexOf( ':' );
	const key = arg.slice( 0, separator );
	const query = arg.slice( separator + 1 );

	let results = await search( query, 'cc0,pdm' );
	let attribution = false;

	if ( results.length === 0 ) {
		results = await search( query, 'by,by-sa' );
		attribution = true;
	}

	if ( results.length === 0 ) {
		console.error( `no image for ${ key } (${ query })` );
		continue;
	}

	const pick = results[ 0 ];
	out[ key ] = {
		url: pick.url,
		title: ( pick.title ?? query ).replace( /\s+/g, ' ' ).trim().slice( 0, 90 ),
		creator: pick.creator ?? '',
		license: `${ pick.license }${ pick.license_version ? ' ' + pick.license_version : '' }`,
		attribution_required: attribution,
		source: pick.foreign_landing_url ?? '',
	};
}

process.stdout.write( JSON.stringify( out, null, '\t' ) + '\n' );
