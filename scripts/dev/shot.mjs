#!/usr/bin/env node
/**
 * Screenshot a page of the running local site.
 *
 * Design work needs looking at, not just reading — this is how a theme's
 * rendered output gets reviewed. Uses the puppeteer that pa11y-ci already
 * brings in, so it adds no dependency of its own.
 *
 * Usage: node scripts/dev/shot.mjs <url> <output.png> [width] [full]
 *
 *   node scripts/dev/shot.mjs http://localhost:8080/ /tmp/home.png
 *   node scripts/dev/shot.mjs http://localhost:8081/shop/ /tmp/shop.png 1440 full
 *   node scripts/dev/shot.mjs http://localhost:8080/ /tmp/mobile.png 390 full
 *
 * `full` captures the whole scrollable page rather than the viewport.
 */

import puppeteer from 'puppeteer';

const [ url, out, widthArg, fullArg ] = process.argv.slice( 2 );

if ( ! url || ! out ) {
	console.error( 'Usage: shot.mjs <url> <output.png> [width] [full]' );
	process.exit( 2 );
}

const width = Number( widthArg || 1440 );

if ( ! Number.isFinite( width ) || width < 200 ) {
	console.error( `Invalid width: ${ widthArg }` );
	process.exit( 2 );
}

const browser = await puppeteer.launch( { args: [ '--no-sandbox' ] } );

try {
	const page = await browser.newPage();
	await page.setViewport( { width, height: 1000, deviceScaleFactor: 1 } );

	const response = await page.goto( url, { waitUntil: 'networkidle2', timeout: 60000 } );

	if ( response && ! response.ok() ) {
		console.error( `Warning: ${ url } returned ${ response.status() }` );
	}

	// Give webfonts and any lazy images a moment to settle before capturing.
	await new Promise( ( resolve ) => setTimeout( resolve, 1200 ) );

	await page.screenshot( { path: out, fullPage: fullArg === 'full' } );
	console.log( `saved ${ out } (${ width }px${ fullArg === 'full' ? ', full page' : '' })` );
} finally {
	await browser.close();
}
