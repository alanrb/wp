/**
 * pa11y-ci configuration.
 *
 * The scanned host comes from WP_URL rather than a hardcoded port, because
 * each client now runs as its own Docker Compose project on its own port
 * (piano :8080, jam :8081). A hardcoded 8080 would happily scan a different
 * client's site and report a clean pass that says nothing about the theme
 * under test — verify.sh checks for exactly that and refuses to continue.
 */
const base = ( process.env.WP_URL || 'http://localhost:8080' ).replace( /\/+$/, '' );

module.exports = {
	defaults: {
		standard: 'WCAG2AA',
		timeout: 30000,
		chromeLaunchConfig: { args: [ '--no-sandbox' ] },
	},
	urls: [ `${ base }/`, `${ base }/shop/` ],
};
