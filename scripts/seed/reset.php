<?php
/**
 * Remove seeded demo content so a seeder can be re-run from clean.
 *
 * Deletes every product, every attachment, and the seeded pages and posts.
 * Site data only — never touches theme files.
 *
 * Run: npm run seed:reset
 *
 * @package client-themes
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$deleted = 0;

foreach ( array( 'product', 'attachment' ) as $type ) {
	$ids = get_posts(
		array(
			'post_type'   => $type,
			'post_status' => 'any',
			'numberposts' => -1,
			'fields'      => 'ids',
		)
	);

	foreach ( $ids as $id ) {
		if ( 'attachment' === $type ) {
			wp_delete_attachment( $id, true );
		} else {
			wp_delete_post( $id, true );
		}
		$deleted++;
	}
}

WP_CLI::success( "Removed $deleted seeded items (products and media)." );
