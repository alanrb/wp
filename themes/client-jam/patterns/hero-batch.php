<?php
/**
 * Title: Batch hero
 * Slug: client-jam/hero-batch
 * Categories: banner, featured
 * Description: A jar-label opening — what is in the pan this week, set on damson with the batch details read like a label.
 *
 * @package client-jam
 */

?>
<!-- wp:group {"align":"full","style":{"spacing":{"padding":{"top":"var:preset|spacing|70","bottom":"var:preset|spacing|70"}}},"backgroundColor":"damson","textColor":"sugar","layout":{"type":"constrained","wideSize":"1220px"}} -->
<div class="wp-block-group alignfull has-sugar-color has-damson-background-color has-text-color has-background" style="padding-top:var(--wp--preset--spacing--70);padding-bottom:var(--wp--preset--spacing--70)">
	<!-- wp:columns {"align":"wide","verticalAlignment":"bottom","style":{"spacing":{"blockGap":{"top":"var:preset|spacing|50","left":"var:preset|spacing|60"}}}} -->
	<div class="wp-block-columns alignwide are-vertically-aligned-bottom">
		<!-- wp:column {"verticalAlignment":"bottom","width":"62%"} -->
		<div class="wp-block-column is-vertically-aligned-bottom" style="flex-basis:62%">
			<!-- wp:heading {"level":1,"style":{"typography":{"lineHeight":"1.05"}},"textColor":"sugar","fontSize":"xx-large"} -->
			<h1 class="wp-block-heading has-sugar-color has-text-color has-xx-large-font-size" style="line-height:1.05">Fruit in, sugar in, nothing else</h1>
			<!-- /wp:heading -->

			<!-- wp:paragraph {"style":{"spacing":{"margin":{"top":"var:preset|spacing|40"}},"typography":{"lineHeight":"1.55"}},"textColor":"muslin","fontSize":"large"} -->
			<p class="has-muslin-color has-text-color has-large-font-size" style="margin-top:var(--wp--preset--spacing--40);line-height:1.55">We cook in twelve-kilo copper pans, in batches small enough to watch. No pectin, no preservative, no concentrate — which is why the set varies a little with the weather and the fruit.</p>
			<!-- /wp:paragraph -->

			<!-- wp:buttons {"style":{"spacing":{"margin":{"top":"var:preset|spacing|50"}}}} -->
			<div class="wp-block-buttons" style="margin-top:var(--wp--preset--spacing--50)">
				<!-- wp:button {"style":{"color":{"background":"var:preset|color|setting","text":"var:preset|color|sugar"}}} -->
				<div class="wp-block-button"><a class="wp-block-button__link has-text-color has-background wp-element-button" href="/shop/" style="color:var(--wp--preset--color--sugar);background-color:var(--wp--preset--color--setting)">Shop the jars</a></div>
				<!-- /wp:button -->

				<!-- wp:button {"className":"is-style-outline","style":{"color":{"background":"transparent","text":"var:preset|color|sugar"},"border":{"color":"var:preset|color|copper","width":"1px"}}} -->
				<div class="wp-block-button is-style-outline"><a class="wp-block-button__link has-border-color wp-element-button" href="/wholesale/" style="border-color:var(--wp--preset--color--copper);border-width:1px;color:var(--wp--preset--color--sugar);background:transparent">Trade and wholesale</a></div>
				<!-- /wp:button -->
			</div>
			<!-- /wp:buttons -->
		</div>
		<!-- /wp:column -->

		<!-- wp:column {"verticalAlignment":"bottom","style":{"border":{"top":{"color":"var:preset|color|copper","style":"solid","width":"1px"}},"spacing":{"padding":{"top":"var:preset|spacing|30"}}}} -->
		<div class="wp-block-column is-vertically-aligned-bottom" style="border-top-color:var(--wp--preset--color--copper);border-top-style:solid;border-top-width:1px;padding-top:var(--wp--preset--spacing--30)">
			<!-- wp:paragraph {"textColor":"muslin","fontSize":"small","style":{"typography":{"fontWeight":"600","letterSpacing":"0.08em"}}} -->
			<p class="has-muslin-color has-text-color has-small-font-size" style="font-weight:600;letter-spacing:0.08em">In the pan this week</p>
			<!-- /wp:paragraph -->

			<!-- wp:paragraph {"textColor":"sugar","fontSize":"large","style":{"typography":{"fontFamily":"var:preset|font-family|label"}}} -->
			<p class="has-sugar-color has-text-color has-large-font-size" style="font-family:var(--wp--preset--font-family--label)">Damson &amp; bay<br>Seville marmalade<br>Greengage</p>
			<!-- /wp:paragraph -->

			<!-- wp:paragraph {"textColor":"muslin","fontSize":"small","style":{"spacing":{"margin":{"top":"var:preset|spacing|30"}}}} -->
			<p class="has-muslin-color has-text-color has-small-font-size" style="margin-top:var(--wp--preset--spacing--30)">Batch sizes are listed on every jar, alongside the orchard the fruit came from.</p>
			<!-- /wp:paragraph -->
		</div>
		<!-- /wp:column -->
	</div>
	<!-- /wp:columns -->
</div>
<!-- /wp:group -->
