#!/usr/bin/env node
/**
 * Turn `wp theme-check run <theme> --format=json` output (read from stdin)
 * into a human-readable report, and decide the run's verdict.
 *
 * Severity is taken from each row's `type` COLUMN, never from a substring of
 * the whole line. Theme Check emits INFO/WARNING/RECOMMENDED rows whose text
 * can legitimately contain the word "required" (for example the theme-tags
 * handbook URL under .../review/required/theme-tags/, and the nav-menu
 * RECOMMENDED notice "it is required to use the WordPress nav_menu
 * functionality"), so grepping the whole output reports REQUIRED-level
 * problems on a perfectly legitimate theme.
 *
 * Exit status:
 *   0  Theme Check ran and reported no REQUIRED-level rows
 *   1  Theme Check ran and reported at least one REQUIRED-level row
 *   2  the input is not a parseable Theme Check result table, so the run
 *      proved nothing and the caller must fail closed
 */

let raw = '';

process.stdin.setEncoding( 'utf8' );
process.stdin.on( 'data', ( chunk ) => {
	raw += chunk;
} );

process.stdin.on( 'end', () => {
	const trimmed = raw.trim();

	// Empty output is not "zero findings" — wp-cli prints `[]` for that. It
	// means the command never got as far as rendering a result table.
	if ( trimmed === '' ) {
		process.exit( 2 );
	}

	let rows;
	try {
		rows = JSON.parse( trimmed );
	} catch {
		process.exit( 2 );
	}

	if ( ! Array.isArray( rows ) ) {
		process.exit( 2 );
	}

	let required = 0;
	const lines = [];

	for ( const row of rows ) {
		if ( ! row || typeof row !== 'object' || Array.isArray( row ) ) {
			process.exit( 2 );
		}
		if ( ! ( 'type' in row ) || ! ( 'value' in row ) ) {
			process.exit( 2 );
		}

		const type = String( row.type ?? '' ).trim().toUpperCase();
		if ( type === 'REQUIRED' ) {
			required += 1;
		}
		lines.push( `${ type === '' ? 'UNKNOWN' : type }\t${ String( row.value ?? '' ) }` );
	}

	if ( lines.length > 0 ) {
		process.stdout.write( lines.join( '\n' ) + '\n' );
	}

	process.exit( required > 0 ? 1 : 0 );
} );
