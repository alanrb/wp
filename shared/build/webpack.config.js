/**
 * Shared webpack configuration for every client theme.
 * Themes require this file so build behaviour stays identical across clients.
 *
 * Why every scaffolded theme's package.json hard-codes a literal
 * `browserslist` array instead of the usual `"extends @wordpress/browserslist-config"`:
 *
 * webpack 5.110.3's browserslist target handler resolves an `extends` query
 * relative to the build's current working directory, not relative to this
 * monorepo's node_modules. A theme built from a THEMES_DIR outside this repo
 * (every build.bats test does this, and so does any real THEMES_DIR override)
 * therefore cannot resolve the `@wordpress/browserslist-config` module and
 * the build crashes with MODULE_NOT_FOUND. Using a literal array of browser
 * queries has no `extends` node, so this resolution never happens and the
 * build works regardless of cwd.
 *
 * The array in base/theme-template/package.json was copied verbatim from
 * @wordpress/browserslist-config@6.54.0's index.js. It is a snapshot, not a
 * live reference, so it will not track future changes to that package.
 *
 * If this webpack regression is fixed upstream (or @wordpress/scripts pins
 * a webpack version without it): change
 * base/theme-template/package.json's "browserslist" field back to
 * "extends @wordpress/browserslist-config" and re-run
 * `npx bats tests/scripts/build.bats` to confirm the build still passes
 * against a non-default THEMES_DIR.
 */
const defaultConfig = require( '@wordpress/scripts/config/webpack.config' );

module.exports = {
	...defaultConfig,
	// wp-scripts defaults to src/index.js -> build/. That is what every theme uses.
};
