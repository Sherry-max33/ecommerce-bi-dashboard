-- Table names: raw_<csv_filename_without_extension>
-- olist_customers_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_customers_dataset (
    customer_id               text,
    customer_unique_id        text,
    customer_zip_code_prefix  text,
    customer_city             text,
    customer_state            text
);

-- olist_geolocation_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_geolocation_dataset (
    geolocation_zip_code_prefix text,
    geolocation_lat             numeric,
    geolocation_lng             numeric,
    geolocation_city            text,
    geolocation_state           text
);

-- olist_order_items_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_order_items_dataset (
    order_id             text,
    order_item_id        numeric,
    product_id           text,
    seller_id            text,
    shipping_limit_date  timestamp,
    price                numeric,
    freight_value        numeric
);

-- olist_order_payments_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_order_payments_dataset (
    order_id               text,
    payment_sequential     numeric,
    payment_type           text,
    payment_installments   numeric,
    payment_value          numeric
);

-- olist_order_reviews_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_order_reviews_dataset (
    review_id                 text,
    order_id                  text,
    review_score              numeric,
    review_comment_title      text,
    review_comment_message    text,
    review_creation_date      timestamp,
    review_answer_timestamp   timestamp
);

-- olist_orders_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_orders_dataset (
    order_id                        text,
    customer_id                     text,
    order_status                    text,
    order_purchase_timestamp        timestamp,
    order_approved_at               timestamp,
    order_delivered_carrier_date    timestamp,
    order_delivered_customer_date   timestamp,
    order_estimated_delivery_date   timestamp
);

-- olist_products_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_products_dataset (
    product_id                  text,
    product_category_name       text,
    product_name_lenght         numeric,
    product_description_lenght  numeric,
    product_photos_qty          numeric,
    product_weight_g            numeric,
    product_length_cm           numeric,
    product_height_cm           numeric,
    product_width_cm            numeric
);

-- olist_sellers_dataset.csv
CREATE TABLE IF NOT EXISTS raw_olist_sellers_dataset (
    seller_id              text,
    seller_zip_code_prefix text,
    seller_city            text,
    seller_state           text
);

-- product_category_name_translation.csv
CREATE TABLE IF NOT EXISTS raw_product_category_name_translation (
    product_category_name          text,
    product_category_name_english  text
);
