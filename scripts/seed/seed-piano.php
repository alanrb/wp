<?php
/**
 * Demo content for the Piano Store & Services theme.
 *
 * Instruments, service bookings, service pages and workshop notes. All images
 * are CC0 or public-domain marked, so a client site carries no attribution
 * obligation.
 *
 * Run: npm run seed -- piano
 *
 * @package client-piano
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

require_once __DIR__ . '/seed-lib.php';

WP_CLI::log( 'Seeding Piano Store & Services...' );

seed_remove_defaults();
seed_store_defaults();

/*
 * All CC0 or public-domain marked, so a delivered client site owes no
 * attribution. Note that openly-licensed photography of MODERN pianos barely
 * exists — the freely-licensed pool is dominated by museum pieces and
 * historical illustrations. Period images are therefore assigned to the period
 * instruments, where they read as plausible, and photographs to the modern
 * ones. A real client would replace all of these with pictures of their own
 * stock, which is the only honest way to sell a specific instrument anyway.
 */
$img = array(
	'steinway'  => 'https://upload.wikimedia.org/wikipedia/commons/d/df/Steinway_grand_piano_interior.JPG',
	'bluthner'  => 'https://live.staticflickr.com/7027/6626882635_1325c7feec_b.jpg',
	'yamaha'    => 'https://pd.w.org/2022/08/1826309b9cca2be04.81789319-2048x1360.jpg',
	'kawai'     => 'https://upload.wikimedia.org/wikipedia/commons/d/da/Steinway_grand_piano_-_pedals.jpg',
	'bechstein' => 'https://images.rawpixel.com/editor_1024/cHJpdmF0ZS9zdGF0aWMvZmlsZXMvd2Vic2l0ZS8yMDIyLTA5L21ldDUwNDI4OC1pbWFnZS5qcGc.jpg',
	'digital'   => 'https://live.staticflickr.com/206/460082542_971c4edf33_b.jpg',
);

/*
 * Instruments. Prices are what these actually fetch second-hand in the UK, so
 * the layout is tested against realistic string lengths rather than "£99.00".
 */
seed_product(
	array(
		'title'    => 'Steinway Model B, restored 1978',
		'sku'      => 'GR-STW-B-78',
		'price'    => 48000,
		'category' => 'Grand pianos',
		'image'    => $img['steinway'],
		'alt'      => 'Pedal lyre of a Steinway grand piano',
		'excerpt'  => 'Rebuilt over fourteen months: new hammers, restrung, action regulated, case refinished in satin ebony.',
		'content'  => '<!-- wp:paragraph --><p>The Model B is the one most pianists would choose if they had the room — seven feet of it, with a bass that never turns muddy. This example came out of a Manchester teaching studio and had been played hard, which is a better history than it sounds: hard-played instruments have usually been maintained.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>We restrung it, fitted Renner hammers, rebushed the action and refinished the case. It has been sitting in the showroom settling for four months and holds its tuning.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Delivery, placement and the first two tunings are included.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Blüthner Model 6, 1912',
		'sku'      => 'GR-BLU-6-12',
		'price'    => 32000,
		'category' => 'Grand pianos',
		'image'    => $img['bluthner'],
		'alt'      => 'Strings and soundboard inside a grand piano',
		'excerpt'  => 'Aliquot-strung Leipzig grand with the singing treble Blüthners are known for. Original soundboard, no cracks.',
		'content'  => '<!-- wp:paragraph --><p>Blüthner added a fourth string in the treble, undamped, to ring in sympathy — the aliquot. It gives the top two octaves a shimmer that no other maker quite matches, and it is the reason people go looking for these specifically.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>This one is honest rather than immaculate: the case shows its age, the soundboard is original and sound, and the action has been rebuilt. If you want a piano that looks new, this is not it. If you want one that sounds like 1912, it is.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Yamaha U3, 1989',
		'sku'      => 'UP-YAM-U3-89',
		'price'    => 4200,
		'category' => 'Upright pianos',
		'image'    => $img['yamaha'],
		'alt'      => 'Upright piano with the fallboard open',
		'excerpt'  => 'The workhorse. 131cm, Japanese-built, and almost impossible to wear out. Ideal for a serious student.',
		'content'  => '<!-- wp:paragraph --><p>If you ask a piano teacher which second-hand upright to buy, most will say a Yamaha U-series, and most will be right. The U3 is the tall one — 131cm, so longer strings and a real bass rather than a thud.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>This is a 1989 Japanese-built example, not a later Indonesian one. New hammers would sharpen it up further, but it plays well as it stands.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Kawai K-300, new',
		'sku'      => 'UP-KAW-K300',
		'price'    => 6950,
		'category' => 'Upright pianos',
		'image'    => $img['kawai'],
		'alt'      => 'Close view of piano keys',
		'excerpt'  => 'New, with a ten-year guarantee. Millwood action parts, quieter practice pedal, warmer than the equivalent Yamaha.',
		'content'  => '<!-- wp:paragraph --><p>The K-300 is the piano we sell most of, because it suits the most people: warm enough for classical, stable enough for a family, and new enough that nothing needs explaining.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Kawai use composite action parts, which do not swell and stick in a centrally heated room the way wooden ones can. Ten-year guarantee, transferable if you sell it on.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Bechstein Model 8, restored 1925',
		'sku'      => 'UP-BEC-8-25',
		'price'    => 7800,
		'category' => 'Upright pianos',
		'image'    => $img['bechstein'],
		'alt'      => 'Antique upright piano in a decorated case',
		'excerpt'  => 'Berlin-built, restrung and refinished. A serious upright with a grand-like touch and an unusually beautiful case.',
		'content'  => '<!-- wp:paragraph --><p>Pre-war Bechstein uprights are built like small grands, and this one has been treated accordingly: restrung, new hammers and dampers, action regulated, case french-polished back to its original finish.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>It is a heavy instrument and needs a solid floor. We will look at the room before delivery and say honestly if it is unsuitable.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Roland FP-90X digital',
		'sku'      => 'DG-ROL-FP90X',
		'price'    => 1899,
		'category' => 'Digital pianos',
		'image'    => $img['digital'],
		'alt'      => 'Hands playing a keyboard',
		'excerpt'  => 'For flats, night practice and anyone who needs headphones. Wooden-key action, and it sounds like an instrument.',
		'content'  => '<!-- wp:paragraph --><p>We stock one digital piano rather than a wall of them, because most of them are not worth the money. This one is: the PHA-50 action mixes wood and composite, so it feels like a piano under the fingers, and the modelled tone responds to how you play rather than triggering samples.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>It is the right answer for a top-floor flat, a night-shift worker, or a household where somebody is practising while somebody else is asleep.</p><!-- /wp:paragraph -->',
	)
);

/* Services sold as bookings. Deliberately image-free — see the seeding note. */
seed_product(
	array(
		'title'    => 'Tuning visit',
		'sku'      => 'SV-TUNE',
		'price'    => 95,
		'category' => 'Services',
		'virtual'  => true,
		'excerpt'  => 'A full tuning at your address, usually about ninety minutes. Minor regulation included.',
		'content'  => '<!-- wp:paragraph --><p>We tune to A440 unless you tell us otherwise. The visit includes small adjustments — a sticking key, a squeaking pedal, a rattling music desk — at no extra cost, because they take minutes and it is daft to charge for them separately.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>If the piano has drifted more than a semitone flat it will need a pitch raise and a second tuning a few weeks later. We will tell you before starting, not after.</p><!-- /wp:paragraph -->',
	)
);

seed_product(
	array(
		'title'    => 'Annual care plan',
		'sku'      => 'SV-CARE',
		'price'    => 170,
		'category' => 'Services',
		'virtual'  => true,
		'single'   => true,
		'excerpt'  => 'Two tunings a year, regulation as needed, and priority if something goes wrong. Cheaper than booking twice.',
		'content'  => '<!-- wp:paragraph --><p>Two visits a year, spaced across the heating seasons, which is when pianos move most. Includes regulation and voicing as required, and puts you at the front of the queue if a string breaks the week before a concert.</p><!-- /wp:paragraph -->',
	)
);

/* Service pages. */
seed_page(
	'Tuning and repair',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">A piano goes out of tune because it is a wooden box under twenty tonnes of string tension, sitting in a room whose humidity changes with the seasons. It is not neglect. It is physics.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">How often</h2><!-- /wp:heading --><!-- wp:paragraph --><p>Twice a year suits most households — once after the heating goes on, once after it goes off. A piano being practised on for several hours a day needs more; one played at weekends needs less. A piano that has not been tuned for a decade needs a conversation before it needs a tuner.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">What we fix on the visit</h2><!-- /wp:heading --><!-- wp:list --><ul class="wp-block-list"><li>Sticking or slow keys</li><li>Squeaking or ineffective pedals</li><li>Buzzing dampers and rattling fittings</li><li>A single broken string, if we have the gauge with us</li></ul><!-- /wp:list --><!-- wp:heading --><h2 class="wp-block-heading">What needs the workshop</h2><!-- /wp:heading --><!-- wp:paragraph --><p>Restringing, hammer replacement, action rebuilds and anything structural. We will quote before removing the instrument, and the quote is what you pay.</p><!-- /wp:paragraph -->',
	'tuning-and-repair'
);

seed_page(
	'Restoration',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Restoring a piano is worth doing when the instrument underneath is worth having. We will tell you when it is not.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>A full restoration runs from six to fourteen months and costs between eight and thirty thousand pounds depending on the instrument. That is more than most people expect, and for a mass-produced upright it is almost never justified — you would be spending twelve thousand pounds on something worth four.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>For a pre-war Bechstein, Blüthner, Bösendorfer or Steinway, the sums change completely. These were built to be rebuilt.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">What we do</h2><!-- /wp:heading --><!-- wp:list --><ul class="wp-block-list"><li>Restringing with new wrest pins and tuning plank work where needed</li><li>New hammers, shanks and flanges, regulated to the maker\'s specification</li><li>Soundboard repair or replacement, and bridge recapping</li><li>Case refinishing, french polish or satin</li></ul><!-- /wp:list --><!-- wp:paragraph --><p>We photograph every stage and send the pictures as we go, so you can see what your money bought rather than taking our word for it.</p><!-- /wp:paragraph -->',
	'restoration'
);

seed_page(
	'Hire',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Uprights by the month, from £45. Delivery, tuning and collection included.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Hire suits three situations: a child who may or may not stick with lessons, a household between houses, and a musician who needs an instrument for a specific project. It is a bad idea only if you already know you want to own one — in that case the money is better spent on the piano.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Terms</h2><!-- /wp:heading --><!-- wp:list --><ul class="wp-block-list"><li>Minimum three months, then monthly</li><li>Delivery and collection included within twenty miles</li><li>One tuning included per six months of hire</li><li>Everything you have paid comes off the price if you buy the instrument</li></ul><!-- /wp:list -->',
	'hire'
);

seed_page(
	'Visit the showroom',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Around thirty instruments, all tuned, all available to play for as long as you like.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Nobody is going to hover. Tell us what you are looking for and roughly what you want to spend, and we will point you at the four or five instruments worth your time, then leave you alone with them. Bring your own music. Bring your teacher if you have one.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Opening hours</h2><!-- /wp:heading --><!-- wp:paragraph --><p>Tuesday to Saturday, 10am to 6pm. Sunday and Monday by appointment, which is often the quieter and better option.</p><!-- /wp:paragraph --><!-- wp:heading --><h2 class="wp-block-heading">Before you come</h2><!-- /wp:heading --><!-- wp:paragraph --><p>Measure the room, and measure the doorway and any turn on the stairs. It saves a difficult conversation later. If you send us the measurements we will tell you what will and will not fit.</p><!-- /wp:paragraph -->',
	'visit'
);

seed_page(
	'Book a tuning',
	'<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Tell us the make, roughly how old it is, and when it was last tuned.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Tuning visits are £95 and take about ninety minutes. We cover a thirty-mile radius; beyond that we still come, with travel added at cost.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>If the piano has not been touched in more than five years, say so. It probably needs a pitch raise first, which is a separate visit, and it is better for both of us if that is understood before we arrive.</p><!-- /wp:paragraph -->',
	'book-a-tuning'
);

/* Workshop notes. */
seed_post(
	array(
		'title'   => 'Why your piano goes out of tune in October',
		'excerpt' => 'The heating goes on, the air dries out, the soundboard shrinks, and the pitch drops. Every year, without fail.',
		'content' => '<!-- wp:paragraph --><p>A soundboard is a large thin panel of spruce, held under pressure by the strings above it. Spruce takes on and gives up moisture with the air around it, and when it does, it changes shape — the crown flattens slightly, the bearing on the bridge reduces, and the pitch falls.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Central heating dries a room out fast. Within a fortnight of the boiler coming on, most pianos in most houses have dropped noticeably. It affects the middle of the keyboard most, because that is where the soundboard moves most, which is why a piano can sound in tune at the ends and sour in the middle.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>None of this is avoidable and none of it is your fault. It is why we suggest tuning after the heating has settled rather than before.</p><!-- /wp:paragraph -->',
	)
);

seed_post(
	array(
		'title'   => 'What a piano costs after you have bought it',
		'excerpt' => 'Tuning, the occasional regulation, and one move. Budget a couple of hundred a year and nothing will surprise you.',
		'content' => '<!-- wp:paragraph --><p>People ask about the purchase price and rarely about the running cost, which is a shame, because the running cost is the predictable part.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>Two tunings a year is £190, or £170 on a care plan. Regulation — adjusting the action so it responds evenly — is worth doing every five years or so, and runs to a few hundred. Hammers last decades in a domestic instrument and are a workshop job when they go.</p><!-- /wp:paragraph --><!-- wp:paragraph --><p>The cost people forget is moving. A piano move is a specialist job and a house move with a grand in it needs planning weeks ahead, not the night before.</p><!-- /wp:paragraph -->',
	)
);

seed_menu(
	'Primary',
	array(
		'Instruments' => '/shop/',
		'Tuning'      => '/tuning-and-repair/',
		'Restoration' => '/restoration/',
		'Hire'        => '/hire/',
		'Visit'       => '/visit/',
	)
);

WP_CLI::success( 'Piano demo content seeded.' );
