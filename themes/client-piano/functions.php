<?php
/**
 * Piano Store & Services theme functions.
 *
 * @package client-piano
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action(
	'after_setup_theme',
	function () {
		add_theme_support( 'wp-block-styles' );
		add_theme_support( 'responsive-embeds' );
		add_theme_support( 'editor-styles' );

		if ( class_exists( 'WooCommerce' ) ) {
			add_theme_support( 'woocommerce' );
		}
	}
);

add_action(
	'wp_enqueue_scripts',
	function () {
		$asset_file = get_theme_file_path( 'build/index.asset.php' );

		if ( ! file_exists( $asset_file ) ) {
			return;
		}

		$asset = require $asset_file;

		wp_enqueue_style(
			'client-piano-style',
			get_theme_file_uri( 'build/style-index.css' ),
			array(),
			$asset['version']
		);

		wp_enqueue_script(
			'client-piano-script',
			get_theme_file_uri( 'build/index.js' ),
			$asset['dependencies'],
			$asset['version'],
			true
		);
	}
);
