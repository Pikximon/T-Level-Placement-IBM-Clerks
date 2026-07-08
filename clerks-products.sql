-- ================================================================
--  CLERKS SHOE STORE — Full Product Database
--  Compatible with: MySQL 8+, PostgreSQL 13+, SQLite 3.35+
-- ================================================================
--
--  SCHEMA OVERVIEW (5 tables)
--  ─────────────────────────────────────────────────────────────
--  products          — one row per shoe (scalar fields only)
--  product_colours   — one row per colour variant per product
--  product_sizes     — one row per available size per product
--  product_oos       — one row per out-of-stock size per product
--  product_features  — one row per feature bullet per product
--
--  RELATIONSHIPS
--  ─────────────────────────────────────────────────────────────
--  product_colours.product_id  → products.id
--  product_sizes.product_id    → products.id
--  product_oos.product_id      → products.id
--  product_features.product_id → products.id
--
--  USEFUL QUERIES TO GET YOU STARTED
--  ─────────────────────────────────────────────────────────────
--  All products in the sports store:
--    SELECT * FROM products WHERE store_type = 'sports';
--
--  All Running shoes under £100:
--    SELECT name, price FROM products
--    WHERE category = 'Running' AND price < 100;
--
--  All colours for a product:
--    SELECT colour_name, hex_code, img_url
--    FROM product_colours
--    WHERE product_id = 'sp1';
--
--  Products on sale, sorted by biggest discount:
--    SELECT name, price, was_price,
--           ROUND((1 - price / was_price) * 100) AS discount_pct
--    FROM products
--    WHERE was_price IS NOT NULL
--    ORDER BY discount_pct DESC;
--
--  Full product detail joined (MySQL / SQLite):
--    SELECT p.id, p.name, p.price,
--           GROUP_CONCAT(DISTINCT c.colour_name) AS colours,
--           GROUP_CONCAT(DISTINCT s.size)         AS sizes,
--           GROUP_CONCAT(DISTINCT f.feature)      AS features
--    FROM products p
--    LEFT JOIN product_colours  c ON c.product_id = p.id
--    LEFT JOIN product_sizes    s ON s.product_id = p.id
--    LEFT JOIN product_features f ON f.product_id = p.id
--    GROUP BY p.id;
-- ================================================================


-- ----------------------------------------------------------------
-- 0.  SAFETY — drop tables if re-running this script
--     (order matters: children before parent)
-- ----------------------------------------------------------------
DROP TABLE IF EXISTS product_features;
DROP TABLE IF EXISTS product_oos;
DROP TABLE IF EXISTS product_sizes;
DROP TABLE IF EXISTS product_colours;
DROP TABLE IF EXISTS products;


-- ================================================================
--  TABLE 1 — products
--  One row per shoe. Stores every field that has exactly one value
--  per product (scalar fields). Arrays from the JS object live in
--  their own child tables below.
-- ================================================================
CREATE TABLE products (
    id          VARCHAR(6)     PRIMARY KEY,          -- e.g. 'sp1', 'fm16'
    store_type  VARCHAR(10)    NOT NULL,              -- 'sports' | 'formal'
    name        VARCHAR(100)   NOT NULL,
    brand       VARCHAR(60)    NOT NULL,
    category    VARCHAR(40)    NOT NULL,
    price       DECIMAL(6,2)   NOT NULL,
    was_price   DECIMAL(6,2)   DEFAULT NULL,          -- NULL = not on sale
    rating      DECIMAL(3,1)   NOT NULL,
    reviews     INT            NOT NULL DEFAULT 0,
    img_url     TEXT           NOT NULL,
    description TEXT           NOT NULL,
    is_new      BOOLEAN        NOT NULL DEFAULT FALSE,
    width       VARCHAR(20)    DEFAULT NULL           -- NULL for all sports shoes
);


-- ================================================================
--  TABLE 2 — product_colours
--  One row per colour per product. img_url is NULL when a colour
--  has no dedicated photo (falls back to the product main image).
-- ================================================================
CREATE TABLE product_colours (
    id          INT            PRIMARY KEY AUTO_INCREMENT,
    product_id  VARCHAR(6)     NOT NULL,
    colour_name VARCHAR(40)    NOT NULL,
    hex_code    VARCHAR(10)    NOT NULL,
    img_url     TEXT           DEFAULT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id)
);


-- ================================================================
--  TABLE 3 — product_sizes
--  One row per available size per product.
--  DECIMAL(4,1) supports half sizes like 7.5.
-- ================================================================
CREATE TABLE product_sizes (
    id          INT            PRIMARY KEY AUTO_INCREMENT,
    product_id  VARCHAR(6)     NOT NULL,
    size        DECIMAL(4,1)   NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id)
);


-- ================================================================
--  TABLE 4 — product_oos  (out-of-stock sizes)
--  Only products that actually have OOS sizes appear here.
--  Join this with product_sizes to find which sizes are blocked.
-- ================================================================
CREATE TABLE product_oos (
    id          INT            PRIMARY KEY AUTO_INCREMENT,
    product_id  VARCHAR(6)     NOT NULL,
    size        DECIMAL(4,1)   NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id)
);


-- ================================================================
--  TABLE 5 — product_features
--  One row per bullet-point feature per product.
--  sort_order preserves the original display sequence.
-- ================================================================
CREATE TABLE product_features (
    id          INT            PRIMARY KEY AUTO_INCREMENT,
    product_id  VARCHAR(6)     NOT NULL,
    sort_order  TINYINT        NOT NULL DEFAULT 0,
    feature     VARCHAR(120)   NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id)
);


-- ================================================================
--  DATA — products  (36 rows: 20 sports + 16 formal)
-- ================================================================
INSERT INTO products
    (id, store_type, name, brand, category, price, was_price, rating, reviews, img_url, description, is_new, width)
VALUES

-- ── Sports ───────────────────────────────────────────────────────
('sp1',  'sports', 'Clerks Velocity',       'Clerks Velocity',    'Running',    89.99,  129.99, 4.8, 1842,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782122979/magic_edit_TUFITlNaRl9wNHMjMSNkNzVlZWVjZTA5Njk4NGE3YWE0ZmYxOTAzNDBjZDk5ZiM4MjQjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_1_y6hadx.png',
 'Responsive cushioning for everyday training and long runs.', FALSE, NULL),

('sp2',  'sports', 'Clerks Aura',            'Clerks Aura',        'Running',   109.99,  159.99, 4.7, 2103,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296365/Blue_Aura_sakozx.png',
 'Infinite energy return from BOOST midsole with Primeknit+ upper.', FALSE, NULL),

('sp3',  'sports', 'Clerks Apex Runner',     'Clerks Apex Runner', 'Running',    99.99,  139.99, 4.9,  987,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_blue_hwmjgg.png',
 'Premium stability with GEL cushioning and LYTE TRUSS support.', FALSE, NULL),

('sp4',  'sports', 'Clerks Stride Pro',      'Clerks Stride Pro',  'Running',    79.99,  119.99, 4.6,  654,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138169/clerks_stride_pro_sea_salt_b7kitj.png',
 'Plush Fresh Foam X midsole for a super-cushioned, smooth ride.', FALSE, NULL),

('sp5',  'sports', 'Clerks Original',        'Clerks Original',    'Lifestyle',  59.99,   89.99, 4.5,  432,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136966/clerks_apex_runner_orange_e86sbp.png',
 'Chunky retro style meets modern comfort.', TRUE, NULL),

('sp6',  'sports', 'Clerks Velocity',        'Clerks Velocity',    'Basketball', 54.99,   74.99, 4.4,  876,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137773/white_nike_tpbikl.png',
 'Classic 1980s basketball style updated for modern wear.', FALSE, NULL),

('sp7',  'sports', 'Clerks Aura',            'Clerks Aura',        'Outdoor',   114.99,  159.99, 4.8,  321,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296365/Blue_Aura_sakozx.png',
 'GORE-TEX waterproofing meets lightweight trail performance.', FALSE, NULL),

('sp8',  'sports', 'Clerks Apex Runner',     'Clerks Apex Runner', 'Training',   84.99,  109.99, 4.7,  543,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782123546/magic_edit_TUFITlNobi1lTTQjMSNhZDJlOGU2ODNlZGE0N2ExZDU3ZjA3YThjOGNmYTY5MSM1OTAjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_1_mpnlr0.png',
 'Lightweight support for daily training with LYTE TRUSS stability.', TRUE, NULL),

('sp9',  'sports', 'Clerks Velocity',        'Clerks Velocity',    'Lifestyle',  94.99,  134.99, 4.7, 3201,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png',
 'The biggest Air unit ever, designed for all-day lifestyle wear.', FALSE, NULL),

('sp10', 'sports', 'Clerks Aura',            'Clerks Aura',        'Lifestyle',  64.99,   89.99, 4.8, 4521,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296366/Green_Aura_izay6a.png',
 'An icon since 1965. Timeless clean design, endlessly versatile.', FALSE, NULL),

('sp11', 'sports', 'Clerks Stride Pro',      'Clerks Stride Pro',  'Lifestyle',  69.99,     NULL, 4.6, 1876,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138147/clerks_stride_pro_grey_zikgix.png',
 'Classic versatile design with iconic N branding and all-day comfort.', TRUE, NULL),

('sp12', 'sports', 'Clerks Original',        'Clerks Original',    'Lifestyle',  54.99,   74.99, 4.5, 1102,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136964/clerks_apex_runner_black_cxbkvj.png',
 'Born in 1968 — one of the most iconic sneakers ever made.', FALSE, NULL),

('sp13', 'sports', 'Clerks Velocity',        'Clerks Velocity',    'Running',    44.99,   64.99, 4.3,  892,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png',
 'Reliable everyday running shoe, great for beginners.', FALSE, NULL),

('sp14', 'sports', 'Clerks Apex Runner',     'Clerks Apex Runner', 'Running',   119.99,  159.99, 4.9,  441,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_blue_hwmjgg.png',
 'ASICS''s most premium neutral shoe for long-distance comfort.', FALSE, NULL),

('sp15', 'sports', 'Clerks Stride Pro',      'Clerks Stride Pro',  'Training',   79.99,     NULL, 4.6,  213,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138148/clerks_stride_pro_white_zfw1yd.png',
 'High-performance training shoe with rapid direction-change stability.', TRUE, NULL),

('sp16', 'sports', 'Clerks Original',        'Clerks Original',    'Walking',    49.99,   69.99, 4.4,  334,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136963/clerks_apex_runner_white_qvoaiz.png',
 'Retro running style meets everyday walking comfort.', FALSE, NULL),

('sp17', 'sports', 'Clerks Apex Runner',     'Clerks Apex Runner', 'Walking',    44.99,   59.99, 4.5, 1203,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_black_jddt5r.png',
 'Reliable trail and walking shoe with GEL heel cushioning.', FALSE, NULL),

('sp18', 'sports', 'Clerks Velocity',        'Clerks Velocity',    'Basketball', 74.99,  104.99, 4.6,  677,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png',
 'Jordan III-inspired design with Air cushioning for court and street.', FALSE, NULL),

('sp19', 'sports', 'Clerks Original',        'Clerks Original',    'Running',    99.99,  139.99, 4.7,  189,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136965/clerks_apex_runner_blue_and_gold_png_tzec62.png',
 'Clerks''s fastest race-day shoe with carbon plate and elite foam.', FALSE, NULL),

('sp20', 'sports', 'Clerks Aura',            'Clerks Aura',        'Outdoor',    89.99,  119.99, 4.7,  256,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296611/Grey_Aura_mxb5ec.png',
 'Technical trail shoe with aggressive outsole and waterproof upper.', FALSE, NULL),

-- ── Formal ───────────────────────────────────────────────────────
('fm1',  'formal', 'Portland Oxford',        'Clerks', 'Oxford Shoes',  89.99,  119.99, 4.8,  412,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222349/portland_oxford_tan_shoes_kp0ihv.webp',
 'A quintessentially British Oxford in premium full-grain leather.', FALSE, 'Standard'),

('fm2',  'formal', 'Stanford Derby',         'Clerks', 'Derby Shoes',   79.99,  109.99, 4.7,  287,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782290677/brown_standford_derby_gvrxbg.png',
 'Open lacing Derby in supple leather — smart casual at its best.', FALSE, 'Wide'),

('fm3',  'formal', 'Westbourne Loafer',      'Clerks', 'Loafers',       69.99,   99.99, 4.6,  198,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782290791/westborn_loafers_connac_gikya0.png',
 'Hand-burnished leather loafer with classic penny strap detail.', FALSE, 'Standard'),

('fm4',  'formal', 'Hampton Smart Casual',   'Clerks', 'Smart Casual',  59.99,   84.99, 4.5,  156,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/smart_casual_hampton_smart_casual_grey_shoes_ztzgzq.png',
 'Relaxed lace-up that bridges formal and casual dressing.', FALSE, 'Standard'),

('fm5',  'formal', 'Bankside Brogue',        'Clerks', 'Oxford Shoes',  99.99,  139.99, 4.9,  334,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/bankside_brogue_tan_wp6bpe.webp',
 'Intricate wingtip broguing with a punched medallion toe.', FALSE, 'Standard'),

('fm6',  'formal', 'Chelsea Workwear Boot',  'Clerks', 'Workwear',     109.99,  149.99, 4.8,  221,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/workwear_chelsea_workwear_boot_black_mpmwla.png',
 'Classic Chelsea boot with Dainite rubber sole for all-weather use.', TRUE, 'Wide'),

('fm7',  'formal', 'Academy School Shoe',    'Clerks', 'School Shoes',  39.99,   54.99, 4.6,  892,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222349/school_shoes_academy_school_shoes_black_qmieo2.jpg',
 'Durable, polishable leather built to last the school year.', FALSE, 'Extra Wide'),

('fm8',  'formal', 'Kensington Derby',       'Clerks', 'Derby Shoes',   84.99,  114.99, 4.7,  167,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222351/Derby_kensington_derby_shoes_chestnut_tmh4oi.png',
 'Refined everyday Derby with hand-finished leather and clean lines.', TRUE, 'Standard'),

('fm9',  'formal', 'Temple Monk Strap',      'Clerks', 'Smart Casual',  94.99,  124.99, 4.8,  143,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/Smart_casual_temple_monk_strap_tan_kquyfu.png',
 'Double monk strap for the confident business dresser.', FALSE, 'Standard'),

('fm10', 'formal', 'Regent Wholecut Oxford', 'Clerks', 'Oxford Shoes', 129.99,  174.99, 4.9,   88,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/Regent_wholecut_oxford_black_ni4h42.png',
 'Cut from a single piece of leather — the pinnacle of shoemaking craft.', FALSE, 'Standard'),

('fm11', 'formal', 'Borough Commuter',       'Clerks', 'Smart Casual',  64.99,     NULL, 4.5,  312,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293601/Screenshot_2026-06-24_103231_h7llmv.png',
 'Water-resistant leather, shock-absorbing insole, built for city commuting.', TRUE, 'Wide'),

('fm12', 'formal', 'Aldgate Cap Toe',        'Clerks', 'Oxford Shoes',  74.99,   99.99, 4.6,  189,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292799/oxford_shoes_Aldgateap_toes_black_ghlvdg.png',
 'Polished cap-toe Oxford for interviews, boardrooms and formal events.', FALSE, 'Standard'),

('fm13', 'formal', 'Bishopsgate Slip-On',    'Clerks', 'Loafers',       74.99,  104.99, 4.7,  224,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293082/Bishopsgate_slipon_loafers_black_ri0utm.png',
 'Understated business loafer with a smooth leather upper.', FALSE, 'Standard'),

('fm14', 'formal', 'Crown Workwear Derby',   'Clerks', 'Workwear',      79.99,  104.99, 4.6,  198,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292795/Crown_workwear_derby_workwear_black_q8p5cc.png',
 'Anti-fatigue insole and wide fit for those on their feet all day.', FALSE, 'Extra Wide'),

('fm15', 'formal', 'Pioneer School Shoe',    'Clerks', 'School Shoes',  34.99,   49.99, 4.5, 1104,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293393/Screenshot_2026-06-24_102930_hsior7.png',
 'Velcro fastening school shoe for active, younger children.', FALSE, 'Wide'),

('fm16', 'formal', 'Greenwich Chelsea',      'Clerks', 'Workwear',      94.99,  129.99, 4.7,  176,
 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292791/Workwear_greenwich_chelsea_tan_luueph.jpg',
 'Waterproof Chelsea boot that handles British weather and the office.', FALSE, 'Standard');


-- ================================================================
--  DATA — product_colours
-- ================================================================
INSERT INTO product_colours (product_id, colour_name, hex_code, img_url) VALUES
-- sp1
('sp1',  'Red',        '#E53E3E', NULL),
('sp1',  'White',      '#eeeeee', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137773/white_nike_tpbikl.png'),
('sp1',  'Navy',       '#003080', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782127042/Blue_nike_a1ryur.png'),
-- sp2
('sp2',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296365/Blue_Aura_sakozx.png'),
('sp2',  'Pink/White', '#eeeeee', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296363/pink_aura_dz7fml.png'),
('sp2',  'Blue',       '#0055CC', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296364/Black_Aura_fhzknp.png'),
-- sp3
('sp3',  'Blue',       '#1E90FF', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_blue_hwmjgg.png'),
('sp3',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_black_jddt5r.png'),
('sp3',  'Red',        '#CC0000', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782123546/magic_edit_TUFITlNobi1lTTQjMSNhZDJlOGU2ODNlZGE0N2ExZDU3ZjA3YThjOGNmYTY5MSM1OTAjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_1_mpnlr0.png'),
-- sp4
('sp4',  'Sea Salt',   '#B8D4C8', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138169/clerks_stride_pro_sea_salt_b7kitj.png'),
('sp4',  'Black',      '#2D2D2D', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782123956/magic_edit_TUFITlNsTUw3Z3cjMSNhODBhZDNkZjZiMzAzZGQ0NDMyN2NlMDMwZmRkNTExZCM4MTkjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_ahyu8x.png'),
('sp4',  'Green',      '#4CAF50', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138147/clerks_stride_pro_green_yth6cx.png'),
-- sp5
('sp5',  'Orange',     '#FF6B1A', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136966/clerks_apex_runner_orange_e86sbp.png'),
('sp5',  'White',      '#F0F0F0', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136963/clerks_apex_runner_white_qvoaiz.png'),
('sp5',  'Blue',       '#0044BB', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782123920/magic_edit_TUFITlNqeUZvQk0jMSMyNTkxZWIyZTRiMzY4YTU4MWQxNDdjMzVjYjhhYWZhYyM1MDAjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_ognk5l.png'),
-- sp6
('sp6',  'White',      '#ffffff', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137773/white_nike_tpbikl.png'),
('sp6',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png'),
-- sp7
('sp7',  'Black',      '#2D2D2D', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296365/Blue_Aura_sakozx.png'),
('sp7',  'Olive',      '#556B2F', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296609/Olive_Aura_bckj7h.png'),
('sp7',  'Blue',       '#1565C0', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296364/Black_Aura_fhzknp.png'),
-- sp8
('sp8',  'Red',        '#CC2200', NULL),
('sp8',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_black_jddt5r.png'),
('sp8',  'Blue',       '#1E3A8A', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_blue_hwmjgg.png'),
-- sp9
('sp9',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png'),
('sp9',  'White',      '#ffffff', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137773/white_nike_tpbikl.png'),
('sp9',  'Blue',       '#0070DD', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782127042/Blue_nike_a1ryur.png'),
-- sp10
('sp10', 'White/Green','#f5f5f5', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296366/Green_Aura_izay6a.png'),
('sp10', 'White/Navy', '#e8e8e8', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296364/Black_Aura_fhzknp.png'),
-- sp11
('sp11', 'Grey',       '#888899', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138147/clerks_stride_pro_grey_zikgix.png'),
('sp11', 'White',      '#F8F8F8', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138148/clerks_stride_pro_white_zfw1yd.png'),
('sp11', 'Green',      '#2E5B2E', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138147/clerks_stride_pro_green_yth6cx.png'),
-- sp12
('sp12', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136964/clerks_apex_runner_black_cxbkvj.png'),
('sp12', 'Red',        '#CC0000', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136967/clerks_apex_runner_red_yabogu.png'),
('sp12', 'Royal',      '#003399', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136965/clerks_apex_runner_blue_and_gold_png_tzec62.png'),
-- sp13
('sp13', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png'),
('sp13', 'White',      '#ffffff', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137773/white_nike_tpbikl.png'),
('sp13', 'Navy',       '#003080', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782127042/Blue_nike_a1ryur.png'),
-- sp14
('sp14', 'Blue',       '#0044FF', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_blue_hwmjgg.png'),
('sp14', 'Black',      '#222233', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_black_jddt5r.png'),
('sp14', 'Birch',      '#D4C8B0', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136626/clerks_original_birch_tk2zsj.png'),
-- sp15
('sp15', 'White',      '#F0F0F0', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782138148/clerks_stride_pro_white_zfw1yd.png'),
('sp15', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782123956/magic_edit_TUFITlNsTUw3Z3cjMSNhODBhZDNkZjZiMzAzZGQ0NDMyN2NlMDMwZmRkNTExZCM4MTkjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_ahyu8x.png'),
-- sp16
('sp16', 'White',      '#ffffff', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136963/clerks_apex_runner_white_qvoaiz.png'),
('sp16', 'Royal Blue', '#0044BB', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136963/clerks_apex_runner_royal_blue_pi7d5q.png'),
-- sp17
('sp17', 'Black',      '#2a2a2a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136627/clerks_original_black_jddt5r.png'),
('sp17', 'Light Blue', '#E0F0FF', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136628/clerks_original_light_blue_amqejy.png'),
-- sp18
('sp18', 'Black',      '#111111', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137774/black_nike_bta199.png'),
('sp18', 'White',      '#F5F5F5', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782137773/white_nike_tpbikl.png'),
('sp18', 'Red',        '#CC0000', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782122979/magic_edit_TUFITlNaRl9wNHMjMSNkNzVlZWVjZTA5Njk4NGE3YWE0ZmYxOTAzNDBjZDk5ZiM4MjQjI1RSQU5TRk9STUFUSU9OX1JFUVVFU1Q_1_y6hadx.png'),
-- sp19
('sp19', 'Blue/Gold',  '#0022CC', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136965/clerks_apex_runner_blue_and_gold_png_tzec62.png'),
('sp19', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782136964/clerks_apex_runner_black_cxbkvj.png'),
-- sp20
('sp20', 'Steel/Grey', '#556677', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296611/Grey_Aura_mxb5ec.png'),
('sp20', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782296365/Blue_Aura_sakozx.png'),
-- fm1
('fm1',  'Tan',        '#8B6914', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222349/portland_oxford_tan_shoes_kp0ihv.webp'),
('fm1',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222349/portland_oxford_black_shoes_na2ghn.webp'),
-- fm2
('fm2',  'Brown',      '#8B4513', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782290677/brown_standford_derby_gvrxbg.png'),
('fm2',  'Navy',       '#1a1a3a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222351/derby_shoes_stanford_derby_navy_shoes_zifg5z.jpg'),
('fm2',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222351/derby_shoes_stanford_derby_black_shoes_d6q5uc.jpg'),
-- fm3
('fm3',  'Cognac',     '#C8760A', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782290791/westborn_loafers_connac_gikya0.png'),
('fm3',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222351/loafers_westbourne_loafers_black_ftp42x.png'),
-- fm4
('fm4',  'Tan',        '#8B6914', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/smart_casual_hampton_smart_casual_grey_shoes_ztzgzq.png'),
('fm4',  'Grey',       '#888899', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/smart_casual_hampton_smart_casual_grey_shoes_ztzgzq.png'),
-- fm5
('fm5',  'Tan',        '#8B6914', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/bankside_brogue_tan_wp6bpe.webp'),
('fm5',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/bankside_brogue_black_qgsd8u.webp'),
('fm5',  'Chestnut',   '#954535', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/bankside_brogue_chestnut_il7jkz.png'),
-- fm6
('fm6',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/workwear_chelsea_workwear_boot_black_mpmwla.png'),
('fm6',  'Dark Brown', '#3D1F0D', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782291625/Chelsea_Workwear_Boot_mrlnki.png'),
-- fm7
('fm7',  'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222349/school_shoes_academy_school_shoes_black_qmieo2.jpg'),
-- fm8
('fm8',  'Chestnut',   '#954535', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222351/Derby_kensington_derby_shoes_chestnut_tmh4oi.png'),
('fm8',  'Navy',       '#1a1a3a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222351/derby_kensington_derby_shoes_navy_exc5lf.png'),
-- fm9
('fm9',  'Tan',        '#8B6914', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/Smart_casual_temple_monk_strap_tan_kquyfu.png'),
('fm9',  'Burgundy',   '#800020', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/Smart_casual_temple_monk_strap_burgundy_vptkjy.png'),
-- fm10
('fm10', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/Regent_wholecut_oxford_black_ni4h42.png'),
('fm10', 'Cognac',     '#C8760A', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782222350/Regent_wholecut_oxford_cognac_jhemlv.png'),
-- fm11
('fm11', 'Navy',       '#1a1a4a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293601/Screenshot_2026-06-24_103231_h7llmv.png'),
('fm11', 'Khaki',      '#8B7D5A', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293655/Screenshot_2026-06-24_103206_z8doie.png'),
('fm11', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293652/Screenshot_2026-06-24_103131_bvdzl8.png'),
-- fm12
('fm12', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292799/oxford_shoes_Aldgateap_toes_black_ghlvdg.png'),
('fm12', 'Dark Brown', '#3D1F0D', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292798/oxford_shoes_Aldgateap_toes_dark_brown_gdvvsb.png'),
-- fm13
('fm13', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293082/Bishopsgate_slipon_loafers_black_ri0utm.png'),
('fm13', 'Navy',       '#1a1a4a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293073/Bishopsgate_slipon_loafers_navy_gphvwb.png'),
-- fm14
('fm14', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292795/Crown_workwear_derby_workwear_black_q8p5cc.png'),
('fm14', 'Dark Brown', '#3D1F0D', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292796/Crown_workwear_derby_workwear_dark_brown_obqdgw.png'),
-- fm15
('fm15', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782293393/Screenshot_2026-06-24_102930_hsior7.png'),
-- fm16
('fm16', 'Tan',        '#8B6914', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292791/Workwear_greenwich_chelsea_tan_luueph.jpg'),
('fm16', 'Black',      '#1a1a1a', 'https://res.cloudinary.com/dxammbmnb/image/upload/v1782292788/Workwear_greenwich_chelsea_black_bzamym.jpg');


-- ================================================================
--  DATA — product_sizes
-- ================================================================
INSERT INTO product_sizes (product_id, size) VALUES
('sp1', 6),  ('sp1', 7),  ('sp1', 7.5),('sp1', 8),  ('sp1', 8.5),('sp1', 9),  ('sp1', 9.5),('sp1', 10), ('sp1', 11), ('sp1', 12),
('sp2', 6),  ('sp2', 7),  ('sp2', 8),  ('sp2', 9),  ('sp2', 10), ('sp2', 11), ('sp2', 12),
('sp3', 6),  ('sp3', 7),  ('sp3', 8),  ('sp3', 9),  ('sp3', 10), ('sp3', 11), ('sp3', 12),
('sp4', 6),  ('sp4', 7),  ('sp4', 8),  ('sp4', 9),  ('sp4', 10), ('sp4', 11),
('sp5', 7),  ('sp5', 8),  ('sp5', 9),  ('sp5', 10), ('sp5', 11), ('sp5', 12),
('sp6', 7),  ('sp6', 8),  ('sp6', 9),  ('sp6', 10), ('sp6', 11), ('sp6', 12),
('sp7', 7),  ('sp7', 8),  ('sp7', 9),  ('sp7', 10), ('sp7', 11), ('sp7', 12),
('sp8', 6),  ('sp8', 7),  ('sp8', 8),  ('sp8', 9),  ('sp8', 10), ('sp8', 11),
('sp9', 7),  ('sp9', 8),  ('sp9', 9),  ('sp9', 10), ('sp9', 11), ('sp9', 12),
('sp10',6),  ('sp10',7),  ('sp10',8),  ('sp10',9),  ('sp10',10), ('sp10',11), ('sp10',12),
('sp11',7),  ('sp11',8),  ('sp11',9),  ('sp11',10), ('sp11',11), ('sp11',12),
('sp12',7),  ('sp12',8),  ('sp12',9),  ('sp12',10), ('sp12',11),
('sp13',6),  ('sp13',7),  ('sp13',8),  ('sp13',9),  ('sp13',10), ('sp13',11), ('sp13',12),
('sp14',7),  ('sp14',8),  ('sp14',9),  ('sp14',10), ('sp14',11), ('sp14',12),
('sp15',7),  ('sp15',8),  ('sp15',9),  ('sp15',10), ('sp15',11), ('sp15',12),
('sp16',7),  ('sp16',8),  ('sp16',9),  ('sp16',10), ('sp16',11),
('sp17',6),  ('sp17',7),  ('sp17',8),  ('sp17',9),  ('sp17',10), ('sp17',11), ('sp17',12),
('sp18',7),  ('sp18',8),  ('sp18',9),  ('sp18',10), ('sp18',11), ('sp18',12),
('sp19',7),  ('sp19',8),  ('sp19',9),  ('sp19',10), ('sp19',11),
('sp20',7),  ('sp20',8),  ('sp20',9),  ('sp20',10), ('sp20',11), ('sp20',12),
('fm1', 6),  ('fm1', 7),  ('fm1', 8),  ('fm1', 9),  ('fm1', 10), ('fm1', 11), ('fm1', 12),
('fm2', 7),  ('fm2', 8),  ('fm2', 9),  ('fm2', 10), ('fm2', 11), ('fm2', 12),
('fm3', 7),  ('fm3', 8),  ('fm3', 9),  ('fm3', 10), ('fm3', 11),
('fm4', 7),  ('fm4', 8),  ('fm4', 9),  ('fm4', 10), ('fm4', 11), ('fm4', 12),
('fm5', 7),  ('fm5', 8),  ('fm5', 9),  ('fm5', 10), ('fm5', 11), ('fm5', 12),
('fm6', 7),  ('fm6', 8),  ('fm6', 9),  ('fm6', 10), ('fm6', 11), ('fm6', 12),
('fm7', 1),  ('fm7', 2),  ('fm7', 3),  ('fm7', 4),  ('fm7', 5),  ('fm7', 6),  ('fm7', 7),
('fm8', 7),  ('fm8', 8),  ('fm8', 9),  ('fm8', 10), ('fm8', 11),
('fm9', 7),  ('fm9', 8),  ('fm9', 9),  ('fm9', 10), ('fm9', 11),
('fm10',7),  ('fm10',8),  ('fm10',9),  ('fm10',10), ('fm10',11),
('fm11',7),  ('fm11',8),  ('fm11',9),  ('fm11',10), ('fm11',11), ('fm11',12),
('fm12',7),  ('fm12',8),  ('fm12',9),  ('fm12',10), ('fm12',11), ('fm12',12),
('fm13',7),  ('fm13',8),  ('fm13',9),  ('fm13',10), ('fm13',11), ('fm13',12),
('fm14',7),  ('fm14',8),  ('fm14',9),  ('fm14',10), ('fm14',11), ('fm14',12), ('fm14',13),
('fm15',1),  ('fm15',2),  ('fm15',3),  ('fm15',4),  ('fm15',5),  ('fm15',6),
('fm16',7),  ('fm16',8),  ('fm16',9),  ('fm16',10), ('fm16',11);


-- ================================================================
--  DATA — product_oos  (only 5 products have any OOS sizes)
-- ================================================================
INSERT INTO product_oos (product_id, size) VALUES
('sp1', 7.5),
('sp1', 12),
('sp4', 6),
('fm4', 12),
('fm9', 7);


-- ================================================================
--  DATA — product_features
-- ================================================================
INSERT INTO product_features (product_id, sort_order, feature) VALUES
('sp1', 1,'React foam midsole'),     ('sp1', 2,'Waffle outsole'),            ('sp1', 3,'Flywire lacing'),             ('sp1', 4,'Breathable mesh'),
('sp2', 1,'BOOST midsole'),          ('sp2', 2,'Primeknit+ upper'),          ('sp2', 3,'Continental rubber'),         ('sp2', 4,'Linear Energy Push'),
('sp3', 1,'GEL cushioning'),         ('sp3', 2,'LYTE TRUSS stability'),      ('sp3', 3,'FF BLAST+ midsole'),          ('sp3', 4,'Engineered mesh'),
('sp4', 1,'Fresh Foam X midsole'),   ('sp4', 2,'Knit bootie upper'),         ('sp4', 3,'Ultra Heel counter'),         ('sp4', 4,'Blown rubber outsole'),
('sp5', 1,'RS cushioning'),          ('sp5', 2,'Mixed upper materials'),     ('sp5', 3,'Rubber outsole'),             ('sp5', 4,'Padded collar'),
('sp6', 1,'Foam midsole'),           ('sp6', 2,'Herringbone traction'),      ('sp6', 3,'Low-cut collar'),             ('sp6', 4,'Synthetic leather upper'),
('sp7', 1,'GORE-TEX waterproof'),    ('sp7', 2,'TRAXION outsole'),           ('sp7', 3,'Continental rubber'),         ('sp7', 4,'Reinforced toe cap'),
('sp8', 1,'FF BLAST midsole'),       ('sp8', 2,'LYTE TRUSS support'),        ('sp8', 3,'Engineered mesh'),            ('sp8', 4,'AHAR outsole'),
('sp9', 1,'270-degree Air unit'),    ('sp9', 2,'Mesh upper'),                ('sp9', 3,'Foam midsole'),               ('sp9', 4,'Durable rubber outsole'),
('sp10',1,'Full-grain leather upper'),('sp10',2,'Cushioned sockliner'),      ('sp10',3,'Rubber cupsole'),             ('sp10',4,'Perforated 3-stripe detail'),
('sp11',1,'ENCAP midsole'),          ('sp11',2,'Suede and mesh upper'),      ('sp11',3,'EVA foam padding'),           ('sp11',4,'Rubber outsole'),
('sp12',1,'Suede leather upper'),    ('sp12',2,'Formstrip branding'),        ('sp12',3,'EVA cushioning'),             ('sp12',4,'Rubber outsole'),
('sp13',1,'Foam midsole'),           ('sp13',2,'Breathable mesh upper'),     ('sp13',3,'Rubber outsole'),             ('sp13',4,'Padded collar'),
('sp14',1,'FF BLAST+ ECO midsole'),  ('sp14',2,'LiteTrax-X outsole'),        ('sp14',3,'PureGEL technology'),         ('sp14',4,'Jacquard mesh upper'),
('sp15',1,'Ndurance outsole'),       ('sp15',2,'FuelCell midsole'),          ('sp15',3,'Stable support frame'),       ('sp15',4,'Mesh upper'),
('sp16',1,'Rubber outsole'),         ('sp16',2,'Foam midsole'),              ('sp16',3,'Synthetic leather upper'),    ('sp16',4,'Padded collar'),
('sp17',1,'Rearfoot GEL'),           ('sp17',2,'AHAR outsole'),              ('sp17',3,'Ortholite sockliner'),        ('sp17',4,'EVA midsole'),
('sp18',1,'Air cushioning'),         ('sp18',2,'Full-length midsole'),       ('sp18',3,'Rubber outsole'),             ('sp18',4,'Synthetic leather upper'),
('sp19',1,'Carbon fibre plate'),     ('sp19',2,'NITRO Elite foam'),          ('sp19',3,'PWRTAPE overlays'),           ('sp19',4,'Specialised outsole'),
('sp20',1,'TRAXION outsole'),        ('sp20',2,'Continental rubber'),        ('sp20',3,'Waterproof upper'),           ('sp20',4,'EVA midsole'),
('fm1', 1,'Full-grain leather upper'),('fm1', 2,'Leather-lined interior'),   ('fm1', 3,'Goodyear welt'),              ('fm1', 4,'Leather stacked heel'),
('fm2', 1,'Premium calf leather'),   ('fm2', 2,'Cushioned insole'),          ('fm2', 3,'Open lace construction'),     ('fm2', 4,'Rubber-tipped heel'),
('fm3', 1,'Hand-burnished leather'), ('fm3', 2,'Penny strap'),               ('fm3', 3,'Memory foam insole'),         ('fm3', 4,'Non-slip rubber sole'),
('fm4', 1,'Soft tumbled leather'),   ('fm4', 2,'Cushioned footbed'),         ('fm4', 3,'Flexible rubber sole'),       ('fm4', 4,'Twin-needle stitching'),
('fm5', 1,'Wingtip brogue detailing'),('fm5',2,'Hand-crafted medallion toe'),('fm5', 3,'Goodyear welt'),              ('fm5', 4,'Oak bark sole'),
('fm6', 1,'Full-grain leather'),     ('fm6', 2,'Elastic side gussets'),      ('fm6', 3,'Dainite rubber sole'),        ('fm6', 4,'Leather-lined collar'),
('fm7', 1,'Polishable leather'),     ('fm7', 2,'Reinforced toe cap'),        ('fm7', 3,'Cushioned insole'),           ('fm7', 4,'Non-slip outsole'),
('fm8', 1,'Hand-finished leather'),  ('fm8', 2,'Antique brass eyelets'),     ('fm8', 3,'Flex-notch sole'),            ('fm8', 4,'Leather-lined throughout'),
('fm9', 1,'Twin monk buckles'),      ('fm9', 2,'Blake stitch construction'), ('fm9', 3,'Vegetable-tanned leather'),   ('fm9', 4,'Leather sole with rubber heel'),
('fm10',1,'Single-piece leather upper'),('fm10',2,'Hand-sewn welt'),         ('fm10',3,'Oak bark sole'),              ('fm10',4,'Hand-lasted construction'),
('fm11',1,'Water-resistant leather'),('fm11',2,'Shock-absorbing insole'),    ('fm11',3,'Lightweight rubber sole'),    ('fm11',4,'Slip-resistant outsole'),
('fm12',1,'Cap-toe stitching'),      ('fm12',2,'Antique brass eyelets'),     ('fm12',3,'Cork-filled footbed'),        ('fm12',4,'Premium leather uppers'),
('fm13',1,'Smooth leather upper'),   ('fm13',2,'Elasticated gusset'),        ('fm13',3,'Memory foam insole'),         ('fm13',4,'Durable rubber sole'),
('fm14',1,'Wide fit available'),     ('fm14',2,'Reinforced heel counter'),   ('fm14',3,'Anti-fatigue insole'),        ('fm14',4,'Oil-resistant outsole'),
('fm15',1,'Velcro fastening'),       ('fm15',2,'Scuff-resistant toe'),       ('fm15',3,'Wide fit option'),            ('fm15',4,'Breathable lining'),
('fm16',1,'Waterproofed leather'),   ('fm16',2,'Dainite studded sole'),      ('fm16',3,'Elastic gussets'),            ('fm16',4,'Side zip for easy on/off');
