<?php
/**
 * Shared helpers for the demo-content seeders.
 *
 * Demo content is site data, not theme data — none of this ships inside a
 * delivered theme zip. It exists so a client theme can be reviewed against a
 * populated shop rather than empty states.
 *
 * Run inside the cli container: wp eval-file /dist/seed-<theme>.php
 *
 * @package client-themes
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/media.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

/**
 * Find an existing post of a type by title, so seeding twice is harmless.
 *
 * @param string $title Post title.
 * @param string $type  Post type.
 * @return int Post ID, or 0 when absent.
 */
function seed_find( $title, $type ) {
	$found = get_posts(
		array(
			'post_type'        => $type,
			'title'            => $title,
			'post_status'      => 'any',
			'numberposts'      => 1,
			'fields'           => 'ids',
			'suppress_filters' => false,
		)
	);

	return $found ? (int) $found[0] : 0;
}

/**
 * Attach a remote image as the featured image, unless one is already set.
 *
 * @param int    $post_id Post to attach to.
 * @param string $url     Remote image URL.
 * @param string $alt     Alt text.
 * @return void
 */
function seed_featured_image( $post_id, $url, $alt ) {
	if ( '' === $url || get_post_thumbnail_id( $post_id ) ) {
		return;
	}

	$attachment_id = media_sideload_image( $url, $post_id, $alt, 'id' );

	if ( is_wp_error( $attachment_id ) ) {
		WP_CLI::warning( "image failed for post $post_id: " . $attachment_id->get_error_message() );
		return;
	}

	update_post_meta( $attachment_id, '_wp_attachment_image_alt', $alt );
	set_post_thumbnail( $post_id, $attachment_id );
}

/**
 * Create or update a simple WooCommerce product.
 *
 * @param array $args Product fields: title, excerpt, content, price, category,
 *                    image, alt, sku.
 * @return int Product ID.
 */
function seed_product( array $args ) {
	$post_id = seed_find( $args['title'], 'product' );

	$postarr = array(
		'post_title'   => $args['title'],
		'post_content' => $args['content'],
		'post_excerpt' => $args['excerpt'],
		'post_status'  => 'publish',
		'post_type'    => 'product',
	);

	if ( $post_id ) {
		$postarr['ID'] = $post_id;
		wp_update_post( $postarr );
	} else {
		$post_id = wp_insert_post( $postarr );
	}

	if ( is_wp_error( $post_id ) || ! $post_id ) {
		WP_CLI::warning( 'could not create product: ' . $args['title'] );
		return 0;
	}

	wp_set_object_terms( $post_id, 'simple', 'product_type' );
	wp_set_object_terms( $post_id, $args['category'], 'product_cat' );

	update_post_meta( $post_id, '_regular_price', (string) $args['price'] );
	update_post_meta( $post_id, '_price', (string) $args['price'] );
	update_post_meta( $post_id, '_sku', $args['sku'] );
	update_post_meta( $post_id, '_manage_stock', 'no' );
	update_post_meta( $post_id, '_stock_status', 'instock' );
	update_post_meta( $post_id, '_visibility', 'visible' );
	update_post_meta( $post_id, '_virtual', empty( $args['virtual'] ) ? 'no' : 'yes' );
	update_post_meta( $post_id, '_downloadable', 'no' );
	update_post_meta( $post_id, '_sold_individually', empty( $args['single'] ) ? 'no' : 'yes' );

	seed_featured_image( $post_id, $args['image'] ?? '', $args['alt'] ?? $args['title'] );

	WP_CLI::log( '  product: ' . $args['title'] );

	return (int) $post_id;
}

/**
 * Create or update a page built from block markup.
 *
 * @param string $title   Page title.
 * @param string $content Block markup.
 * @param string $slug    Page slug.
 * @return int Page ID.
 */
function seed_page( $title, $content, $slug ) {
	$post_id = seed_find( $title, 'page' );

	$postarr = array(
		'post_title'   => $title,
		'post_name'    => $slug,
		'post_content' => $content,
		'post_status'  => 'publish',
		'post_type'    => 'page',
	);

	if ( $post_id ) {
		$postarr['ID'] = $post_id;
		wp_update_post( $postarr );
	} else {
		$post_id = wp_insert_post( $postarr );
	}

	WP_CLI::log( '  page: ' . $title );

	return (int) $post_id;
}

/**
 * Create or update a blog post.
 *
 * @param array $args Post fields: title, excerpt, content, image, alt.
 * @return int Post ID.
 */
function seed_post( array $args ) {
	$post_id = seed_find( $args['title'], 'post' );

	$postarr = array(
		'post_title'   => $args['title'],
		'post_content' => $args['content'],
		'post_excerpt' => $args['excerpt'],
		'post_status'  => 'publish',
		'post_type'    => 'post',
	);

	if ( $post_id ) {
		$postarr['ID'] = $post_id;
		wp_update_post( $postarr );
	} else {
		$post_id = wp_insert_post( $postarr );
	}

	seed_featured_image( $post_id, $args['image'] ?? '', $args['alt'] ?? $args['title'] );

	WP_CLI::log( '  post: ' . $args['title'] );

	return (int) $post_id;
}

/**
 * Build a primary navigation menu from a list of pages, and assign it to the
 * theme's navigation block.
 *
 * @param string $menu_name Menu name.
 * @param array  $items     Ordered list of [ title => url ].
 * @return void
 */
function seed_menu( $menu_name, array $items ) {
	$menu = wp_get_nav_menu_object( $menu_name );

	if ( ! $menu ) {
		$menu_id = wp_create_nav_menu( $menu_name );
	} else {
		$menu_id = (int) $menu->term_id;
		foreach ( wp_get_nav_menu_items( $menu_id ) as $existing ) {
			wp_delete_post( $existing->ID, true );
		}
	}

	foreach ( $items as $title => $url ) {
		wp_update_nav_menu_item(
			$menu_id,
			0,
			array(
				'menu-item-title'  => $title,
				'menu-item-url'    => $url,
				'menu-item-status' => 'publish',
				'menu-item-type'   => 'custom',
			)
		);
	}

	/*
	 * Block themes do not read classic menus. The Navigation block resolves to
	 * a wp_navigation post, and falls back to listing every published page
	 * alphabetically when none exists — which is why an unseeded site shows
	 * "Cart, Checkout, My account, Sample Page". Write the same links into a
	 * wp_navigation post so the block has something deliberate to render.
	 */
	$markup = '';
	foreach ( $items as $title => $url ) {
		$markup .= sprintf(
			'<!-- wp:navigation-link {"label":"%s","url":"%s","kind":"custom","isTopLevelLink":true} /-->',
			esc_attr( $title ),
			esc_attr( $url )
		);
	}

	$navigation_id = seed_find( $menu_name, 'wp_navigation' );

	$navarr = array(
		'post_title'   => $menu_name,
		'post_content' => $markup,
		'post_status'  => 'publish',
		'post_type'    => 'wp_navigation',
	);

	if ( $navigation_id ) {
		$navarr['ID'] = $navigation_id;
		wp_update_post( $navarr );
	} else {
		wp_insert_post( $navarr );
	}

	WP_CLI::log( '  menu: ' . $menu_name );
}

/**
 * Set store defaults that the seeded copy assumes.
 *
 * Both clients are priced in pounds throughout their product descriptions and
 * service pages, so leaving WooCommerce on its default US dollar would put a
 * "$" beside every "£" in the prose.
 *
 * @return void
 */
function seed_store_defaults() {
	update_option( 'woocommerce_currency', 'GBP' );
	update_option( 'woocommerce_price_thousand_sep', ',' );
	update_option( 'woocommerce_price_decimal_sep', '.' );
	update_option( 'woocommerce_price_num_decimals', 2 );
	update_option( 'woocommerce_default_country', 'GB' );
	update_option( 'woocommerce_weight_unit', 'kg' );

	WP_CLI::log( '  store: prices in GBP' );
}

/**
 * Delete WordPress's default sample content so the demo site is not a mix of
 * seeded content and "Hello world!".
 *
 * @return void
 */
function seed_remove_defaults() {
	foreach ( array( 'Hello world!' => 'post', 'Sample Page' => 'page' ) as $title => $type ) {
		$id = seed_find( $title, $type );
		if ( $id ) {
			wp_delete_post( $id, true );
			WP_CLI::log( '  removed default: ' . $title );
		}
	}
}
