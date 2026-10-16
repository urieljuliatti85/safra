# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_16_050000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.string "scope", default: "read", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_api_tokens_on_company_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id"
    t.string "user_name", null: false
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.string "auditable_label"
    t.jsonb "details", default: {}, null: false
    t.string "request_id"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["company_id", "created_at"], name: "index_audit_logs_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_audit_logs_on_company_id"
    t.index ["request_id"], name: "index_audit_logs_on_request_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "raw_lead_days", default: 1, null: false
    t.boolean "active", default: true, null: false
  end

  create_table "customer_aliases", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.string "name_in_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_customer_aliases_on_company_id"
    t.index ["customer_id", "name_in_order"], name: "index_customer_aliases_on_customer_id_and_name_in_order", unique: true
    t.index ["customer_id"], name: "index_customer_aliases_on_customer_id"
    t.index ["product_id"], name: "index_customer_aliases_on_product_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "short_name", null: false
    t.string "order_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "district"
    t.string "city"
    t.string "state", limit: 2
    t.string "postal_code", limit: 8
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.time "delivery_from"
    t.time "delivery_until"
    t.text "delivery_notes"
    t.index ["company_id", "code"], name: "index_customers_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_customers_on_company_id"
  end

  create_table "cuts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "sector", null: false
    t.string "sector_name", null: false
    t.integer "lead_days", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_cuts_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_cuts_on_company_id"
  end

  create_table "order_imports", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "customer_id", null: false
    t.string "filename", null: false
    t.date "week_start", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", default: "sheet", null: false
    t.index ["company_id", "created_at"], name: "index_order_imports_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_order_imports_on_company_id"
    t.index ["customer_id"], name: "index_order_imports_on_customer_id"
  end

  create_table "order_lines", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.date "delivery_date", null: false
    t.decimal "quantity", precision: 10, scale: 3, null: false
    t.string "unit", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "delivery_date"], name: "index_order_lines_on_company_id_and_delivery_date"
    t.index ["company_id"], name: "index_order_lines_on_company_id"
    t.index ["order_id"], name: "index_order_lines_on_order_id"
    t.index ["product_id"], name: "index_order_lines_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "customer_id", null: false
    t.date "week_start", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_orders_on_company_id"
    t.index ["customer_id", "week_start"], name: "index_orders_on_customer_id_and_week_start", unique: true
    t.index ["customer_id"], name: "index_orders_on_customer_id"
  end

  create_table "production_plan_items", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "production_plan_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 10, scale: 3, null: false
    t.string "unit", null: false
    t.jsonb "breakdown", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_production_plan_items_on_company_id"
    t.index ["product_id"], name: "index_production_plan_items_on_product_id"
    t.index ["production_plan_id"], name: "index_production_plan_items_on_production_plan_id"
  end

  create_table "production_plans", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.date "date", null: false
    t.integer "version", default: 1, null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "date", "version"], name: "index_production_plans_on_company_id_and_date_and_version", unique: true
    t.index ["company_id"], name: "index_production_plans_on_company_id"
  end

  create_table "production_rules", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "product_id", null: false
    t.integer "lead_days", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_production_rules_on_company_id"
    t.index ["product_id"], name: "index_production_rules_on_product_id", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "raw_material_id", null: false
    t.bigint "cut_id"
    t.string "code", null: false
    t.string "name", null: false
    t.string "product_group", null: false
    t.string "unit", default: "kg", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_products_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_products_on_company_id"
    t.index ["cut_id"], name: "index_products_on_cut_id"
    t.index ["raw_material_id"], name: "index_products_on_raw_material_id"
  end

  create_table "purchase_days", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "date"], name: "index_purchase_days_on_company_id_and_date", unique: true
    t.index ["company_id"], name: "index_purchase_days_on_company_id"
  end

  create_table "purchase_plan_items", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "purchase_plan_id", null: false
    t.bigint "raw_material_id", null: false
    t.decimal "kg", precision: 10, scale: 3, null: false
    t.integer "packages"
    t.jsonb "breakdown", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unit", default: "kg", null: false
    t.index ["company_id"], name: "index_purchase_plan_items_on_company_id"
    t.index ["purchase_plan_id"], name: "index_purchase_plan_items_on_purchase_plan_id"
    t.index ["raw_material_id"], name: "index_purchase_plan_items_on_raw_material_id"
  end

  create_table "purchase_plans", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.date "date", null: false
    t.integer "version", default: 1, null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "date", "version"], name: "index_purchase_plans_on_company_id_and_date_and_version", unique: true
    t.index ["company_id"], name: "index_purchase_plans_on_company_id"
  end

  create_table "raw_materials", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "supplier_id"
    t.string "code", null: false
    t.string "name", null: false
    t.decimal "multiply_factor", precision: 10, scale: 3
    t.decimal "kg_per_package", precision: 10, scale: 3
    t.decimal "kg_per_peeled_box", precision: 10, scale: 3
    t.string "purchase_package", default: "kg", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_raw_materials_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_raw_materials_on_company_id"
    t.index ["supplier_id"], name: "index_raw_materials_on_supplier_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stock_counts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "raw_material_id", null: false
    t.date "date", null: false
    t.decimal "kg", precision: 10, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_stock_counts_on_company_id"
    t.index ["raw_material_id", "date"], name: "index_stock_counts_on_raw_material_id_and_date", unique: true
    t.index ["raw_material_id"], name: "index_stock_counts_on_raw_material_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_suppliers_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_suppliers_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "role", default: "office", null: false
    t.boolean "must_change_password", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "platform_admin", default: false, null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "companies"
  add_foreign_key "audit_logs", "companies"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "customer_aliases", "companies"
  add_foreign_key "customer_aliases", "customers"
  add_foreign_key "customer_aliases", "products"
  add_foreign_key "customers", "companies"
  add_foreign_key "cuts", "companies"
  add_foreign_key "order_imports", "companies"
  add_foreign_key "order_imports", "customers"
  add_foreign_key "order_lines", "companies"
  add_foreign_key "order_lines", "orders"
  add_foreign_key "order_lines", "products"
  add_foreign_key "orders", "companies"
  add_foreign_key "orders", "customers"
  add_foreign_key "production_plan_items", "companies"
  add_foreign_key "production_plan_items", "production_plans"
  add_foreign_key "production_plan_items", "products"
  add_foreign_key "production_plans", "companies"
  add_foreign_key "production_rules", "companies"
  add_foreign_key "production_rules", "products"
  add_foreign_key "products", "companies"
  add_foreign_key "products", "cuts"
  add_foreign_key "products", "raw_materials"
  add_foreign_key "purchase_days", "companies"
  add_foreign_key "purchase_plan_items", "companies"
  add_foreign_key "purchase_plan_items", "purchase_plans"
  add_foreign_key "purchase_plan_items", "raw_materials"
  add_foreign_key "purchase_plans", "companies"
  add_foreign_key "raw_materials", "companies"
  add_foreign_key "raw_materials", "suppliers"
  add_foreign_key "sessions", "users"
  add_foreign_key "stock_counts", "companies"
  add_foreign_key "stock_counts", "raw_materials"
  add_foreign_key "suppliers", "companies"
  add_foreign_key "users", "companies"
end
