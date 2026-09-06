<?php
/**
 * Demo content for the Fruit Jam Production theme.
 *
 * Jars, cases, trade pages and recipes. All images are CC0 or public-domain
 * marked, so a client site carries no attribution obligation.
 *
 * Run: npm run seed -- jam
 *
 * @package client-jam
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

require_once __DIR__ . '/seed-lib.php';

WP_CLI::log( 'Seeding Fruit Jam Production...' );

seed_remove_defaults();
seed_store_defaults();

/* All CC0 or public-domain marked — no attribution obligation on a client site. */
$img = array(
	'damson'       => 'https://images.rawpixel.com/editor_1024/czNmcy1wcml2YXRlL3Jhd3BpeGVsX2ltYWdlcy93ZWJzaXRlX2NvbnRlbnQvbHIvcHg1NDk3MTYtaW1hZ2Uta3d2eHE3a2kuanBn.jpg',
	'seville'      => 'https://live.staticflickr.com/1957/30093161307_26f661b0de_b.jpg',
	'greengage'    => 'https://upload.wikimedia.org/wikipedia/commons/b/ba/Plums_-_The_Fruit_Bowl%2C_Brighton_2023-08-23.jpg',
	'raspberry'    => 'https://upload.wikimedia.org/wikipedia/commons/2/26/Raspberry_Jam_Jams.jpg',
	'quince'       => 'https://images.rawpixel.com/editor_1024/cHJpdmF0ZS9zdGF0aWMvaW1hZ2Uvd2Vic2l0ZS8yMDIyLTA0L2xyL2ZycXVpbmNlX2ZydWl0X3BsYW50X2xlYWZfMS1pbWFnZS1reWJhdDJpeC5qcGc.jpg',
	'blackcurrant' => 'https://live.staticflickr.com/65535/55378316072_98e04f36db_b.jpg',
	'gift'         => 'https://upload.wikimedia.org/wikipedia/commons/5/5b/Joseph_Mitry%2C_Preserving_Jar%2C_c._1941%2C_NGA_23184.jpg',
	'kitchen'      => 'https://live.staticflickr.com/65535/49231465022_9b5c27de21_b.jpg',
);

/* Jars. Prices are UK artisan-preserve realistic, not placeholder round numbers. */
seed_product(
	array(
		'title'    => 'Damson and bay, 227g',
		'sku'      => 'JAM-DAM-227',
		'price'    => 5.50,
		'category' => 'Jams',
		'image'    => $img['damson'],
		'alt'      => 'Jar of dark plum jam',
		'excerpt'  => 'Sharp, dark and barely sweet. One bay leaf per pan, which is enough to notice and not enough to name.',
		'content'  => '<!-- wp:paragraph --><p>Damsons are the least obliging fruit we work with — small, sour, and full of stones that have to come out by hand after cooking. They also make the best jam we produce, which is why we keep doing it.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>The bay is there to stop it tasting like every other plum jam. It reads as a savoury note rather than a herb, and it is the reason this one ends up next to cheese as often as toast.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p><strong>Ingredients:</strong> damsons, sugar, bay. <strong>Fruit content:</strong> 55g per 100g.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Seville marmalade, 340g',
		'sku'      => 'MRM-SEV-340',
		'price'    => 6.20,
		'category' => 'Marmalade',
		'image'    => $img['seville'],
		'alt'      => 'Glass jar of marmalade',
		'excerpt'  => 'Thick cut, properly bitter, made in the six weeks a year Sevilles exist. When it is gone it is gone.',
		'content'  => '<!-- wp:paragraph --><p>Seville oranges are in the country from early January to the middle of February and are useless for anything except this. We buy the year\'s supply in one go and cook through the nights.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Thick cut, because thin cut is for people who do not really want marmalade. The bitterness is the point — if it tastes like orange jam, something has gone wrong.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p><strong>Ingredients:</strong> Seville oranges, sugar, lemon. <strong>Fruit content:</strong> 45g per 100g.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Greengage, 227g',
		'sku'      => 'JAM-GRG-227',
		'price'    => 5.80,
		'category' => 'Jams',
		'image'    => $img['greengage'],
		'alt'      => 'Green plums in a bowl',
		'excerpt'  => 'Honeyed and floral, the colour of a bottle held to the light. Three weeks of the year, if the wasps allow it.',
		'content'  => '<!-- wp:paragraph --><p>Greengages are the most fragile thing in the orchard and the most rewarding in the pan. Picked slightly under, they hold their shape; picked ripe, they collapse into something closer to honey.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>We use both, in the same batch, which is why the texture is uneven and deliberately so.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p><strong>Ingredients:</strong> greengages, sugar, lemon. <strong>Fruit content:</strong> 58g per 100g.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Raspberry, 227g',
		'sku'      => 'JAM-RSP-227',
		'price'    => 6.00,
		'category' => 'Jams',
		'image'    => $img['raspberry'],
		'alt'      => 'Raspberry jam in a jar',
		'excerpt'  => 'A short, hot boil so the fruit keeps its perfume. Seeds left in, because taking them out takes the flavour too.',
		'content'  => '<!-- wp:paragraph --><p>Raspberry is the jam most often ruined by overcooking. The perfume goes off with the steam, and what is left is sweet and red and characterless.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Ours boils for under eight minutes. It is a softer set as a result. That is the trade, and we would make it every time.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p><strong>Ingredients:</strong> raspberries, sugar, lemon. <strong>Fruit content:</strong> 60g per 100g.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Quince membrillo, 227g',
		'sku'      => 'PST-QNC-227',
		'price'    => 6.50,
		'category' => 'Fruit pastes',
		'image'    => $img['quince'],
		'alt'      => 'Quince fruit on the tree',
		'excerpt'  => 'Cooked down for six hours until it sets solid and turns the colour of an old penny. For cheese, mostly.',
		'content'  => '<!-- wp:paragraph --><p>Raw quince is inedible — hard, astringent, faintly perfumed. Six hours in the pan turns it into something dense and sliceable that goes darker the longer it cooks.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Traditionally eaten with manchego. Works with any hard sheep or goat cheese, and with cold roast pork.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p><strong>Ingredients:</strong> quince, sugar, lemon. <strong>Fruit content:</strong> 62g per 100g.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Blackcurrant, 227g',
		'sku'      => 'JAM-BLK-227',
		'price'    => 5.50,
		'category' => 'Jams',
		'image'    => $img['blackcurrant'],
		'alt'      => 'Dark berries',
		'excerpt'  => 'The most intense jar we make. Sets hard without pectin because blackcurrants are full of it already.',
		'content'  => '<!-- wp:paragraph --><p>Blackcurrants carry enough natural pectin that they set almost whatever you do, which makes them forgiving to cook and difficult to ruin.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>The flavour is closer to a cordial than a jam — sharp and slightly tannic. Good on scones, better folded through yoghurt.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p><strong>Ingredients:</strong> blackcurrants, sugar. <strong>Fruit content:</strong> 57g per 100g.</p><!-- /wp:paragraph -->',
	)
);

/* Cases and gifts. */
seed_product(
	array(
		'title'    => 'Mixed case, twelve jars',
		'sku'      => 'CSE-MIX-12',
		'price'    => 58.00,
		'category' => 'Cases',
		'image'    => $img['kitchen'],
		'alt'      => 'Preserving jars on a shelf',
		'excerpt'  => 'Any twelve jars, your choice of flavours, packed in straw board. Works out cheaper than buying singly.',
		'content'  => '<!-- wp:paragraph --><p>Tell us the twelve you want in the order notes, or leave it to us and we will send a spread of what came off the pan most recently.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Packed in moulded straw board, not plastic. The box is compostable and so is the padding.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Gift set of three',
		'sku'      => 'GFT-SET-3',
		'price'    => 18.00,
		'category' => 'Cases',
		'image'    => $img['gift'],
		'alt'      => 'Glass preserving jar',
		'excerpt'  => 'Three 110g jars in a board box, with a card saying what they are and when they were made.',
		'content'  => '<!-- wp:paragraph --><p>The set most people send at Christmas: one dark, one sharp, one sweet. Add a message at checkout and we will write it on the card by hand.</p><!-- /wp:paragraph -->',
	)
);

/* Pages. */
seed_page(
	'Wholesale',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">We supply around ninety independent shops, delis and farm cafés. Trade pricing starts at one mixed case.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Terms</h2><!-- /wp:heading --><!-- wp:list --><ul class="wp-block-list"><li>Minimum order: one mixed case, twelve jars</li><li>Lead time: seven to ten days from order</li><li>Jar sizes: 110g, 227g, 340g</li><li>Own label: from forty cases per run</li><li>Shelf life: eighteen months unopened</li><li>SALSA approved, with allergen statements issued per batch</li></ul><!-- /wp:list --><!-- wp:heading --><h2 class="wp-block-heading">Samples</h2><!-- /wp:heading --><!-- wp:paragraph --><p>We will send three jars free to any trade address before you order. Tell us what your customers buy and we will pick accordingly rather than sending our favourites.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Own label</h2><!-- /wp:heading --><!-- wp:paragraph --><p>From forty cases we will make to your recipe or ours, under your label. Artwork needs to be with us three weeks before the run. We will not put your name on something we would not sell under ours, so expect an honest conversation about the recipe first.</p><!-- /wp:paragraph -->',
	'wholesale'
);

seed_page(
	'The kitchen',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">One room, four copper pans, and about nine hours from fruit arriving to jars going into the box.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>We started in 1998 in a domestic kitchen with one pan and a stall on a Saturday market. The equipment has changed and the method has not: small batches, short boils, no pectin, no preservative, no fruit concentrate.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Why copper</h2><!-- /wp:heading --><!-- wp:paragraph --><p>Copper conducts heat fast and evenly, so the pan reaches setting point quickly and comes off the heat before the fruit stews. Stainless steel works, but it takes longer, and the extra minutes cost you the fresh flavour that made the fruit worth buying.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Visiting</h2><!-- /wp:heading --><!-- wp:paragraph --><p>Thursdays at 11am and 2pm, free, about forty minutes. You will see a batch being made and you will be given things to taste. Wear closed shoes and do not bring a pushchair — the floor is wet and the pans are hot.</p><!-- /wp:paragraph -->',
	'the-kitchen'
);

seed_page(
	'Stockists',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">If you would rather buy a jar in person, these are the shops that carry us.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Stock varies — most shops take four or five lines rather than everything, and the seasonal jars sell out quickly. It is worth ringing ahead if you are after something specific.</p><!-- /wp:paragraph --><!-- wp:list --><ul class="wp-block-list"><li>Farm shops and delis across the county</li><li>Selected independent grocers in the city</li><li>Two farmers\' markets, Saturday mornings</li></ul><!-- /wp:list --><!-- wp:paragraph --><p>Shopkeepers: see <a href="/wholesale/">wholesale</a> for trade terms.</p><!-- /wp:paragraph -->',
	'stockists'
);

/* Recipes. */
seed_post(
	array(
		'title'   => 'Damson jam with a hard cheese',
		'excerpt' => 'The simplest thing to do with a sharp jar, and the one worth getting right. Notes on which cheeses hold up.',
		'content' => '<!-- wp:paragraph --><p>Sweet preserves and hard cheese work because the acid cuts the fat. That means the jam has to be sharp enough to do the job — a sugary jam next to cheddar is just two sweet things on a plate.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Damson and bay is the one we reach for. Quince membrillo is the traditional answer and is better with sheep\'s cheese. Blackcurrant is too tannic and fights.</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">What works</h3><!-- /wp:heading --><!-- wp:list --><ul class="wp-block-list"><li>Aged cheddar with damson and bay</li><li>Manchego or any hard sheep cheese with quince</li><li>Fresh goat cheese with greengage</li><li>Blue cheese with raspberry, at a push</li></ul><!-- /wp:list --><!-- wp:paragraph --><p>Take the cheese out of the fridge an hour before. Cold cheese tastes of nothing and the jam has nothing to work against.</p><!-- /wp:paragraph -->',
	)
);

seed_post(
	array(
		'title'   => 'A proper Bakewell, with raspberry jam',
		'excerpt' => 'Shop jam makes a wet Bakewell. A short-boiled jam with real fruit content makes the one you remember.',
		'content' => '<!-- wp:paragraph --><p>The jam layer in a Bakewell has to survive forty minutes in the oven without turning to syrup and soaking the pastry. Commercial jam, thickened with pectin and low on fruit, does exactly that.</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">The method</h3><!-- /wp:heading --><!-- wp:list {"ordered":true} --><ol class="wp-block-list"><li>Blind bake the pastry case properly — fifteen minutes with beans, five without.</li><li>Let it cool completely. Warm pastry plus jam equals a soggy base, every time.</li><li>Spread the jam thinner than you want to. It spreads further as it heats.</li><li>Frangipane on top, almonds scattered, forty minutes at 170°C.</li></ol><!-- /wp:list --><!-- wp:paragraph --><p>Use the raspberry. The seeds are the point — they are what tells you it was made from fruit.</p><!-- /wp:paragraph -->',
	)
);

seed_post(
	array(
		'title'   => 'What to do with the last inch in the jar',
		'excerpt' => 'Do not wash it out. There are three good uses for a nearly-empty jar, and one of them is a salad dressing.',
		'content' => '<!-- wp:paragraph --><p>The last spoonful is the awkward one — too little to spread, too much to rinse away.</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Dressing</h3><!-- /wp:heading --><!-- wp:paragraph --><p>Add oil, vinegar, mustard and salt straight into the jar, put the lid on and shake. The jam dissolves into it and does the work of the honey you would otherwise add.</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Pan sauce</h3><!-- /wp:heading --><!-- wp:paragraph --><p>After frying pork or duck, take the pan off the heat, spoon in the last of a dark jam and a splash of vinegar, and swirl. Ninety seconds, one pan.</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Porridge</h3><!-- /wp:heading --><!-- wp:paragraph --><p>Hot porridge straight into the jar. It loosens what is left and you eat it out of the jar, which is the entire appeal.</p><!-- /wp:paragraph -->',
	)
);

seed_menu(
	'Primary',
	array(
		'Shop'        => '/shop/',
		'The kitchen' => '/the-kitchen/',
		'Wholesale'   => '/wholesale/',
		'Stockists'   => '/stockists/',
		'Recipes'     => '/blog/',
	)
);

WP_CLI::success( 'Jam demo content seeded.' );
