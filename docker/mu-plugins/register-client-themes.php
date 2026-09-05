<?php
/**
 * Plugin Name: Register client themes directory
 * Description: Exposes the repo's themes/ bind mount to WordPress without hiding bundled themes.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

register_theme_directory( WP_CONTENT_DIR . '/client-themes' );
