/**
 * Shared webpack configuration for every client theme.
 * Themes require this file so build behaviour stays identical across clients.
 */
const defaultConfig = require( '@wordpress/scripts/config/webpack.config' );

module.exports = {
	...defaultConfig,
	// wp-scripts defaults to src/index.js -> build/. That is what every theme uses.
};
