# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20181023195537) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "alexas", force: :cascade do |t|
    t.integer "chat_id"
    t.text "device_user"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_alexas_on_chat_id"
  end

  create_table "chat_members", force: :cascade do |t|
    t.integer "chat_id"
    t.integer "member_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "summons_performed", default: 0
    t.index ["chat_id", "member_id"], name: "index_chat_members_on_chat_id_and_member_id", unique: true
    t.index ["chat_id"], name: "index_chat_members_on_chat_id"
    t.index ["member_id"], name: "index_chat_members_on_member_id"
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "telegram_chat", null: false
    t.boolean "quotes_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.boolean "birthdays_enabled", default: false, null: false
  end

  create_table "eight_ball_answers", force: :cascade do |t|
    t.integer "chat_id"
    t.text "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_eight_ball_answers_on_chat_id"
  end

  create_table "luck_histories", force: :cascade do |t|
    t.bigint "member_id"
    t.integer "luck"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_luck_histories_on_member_id"
  end

  create_table "members", force: :cascade do |t|
    t.text "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "luck", default: 50
    t.bigint "telegram_user"
    t.string "first_name"
    t.string "last_name"
    t.date "birthday"
  end

  create_table "photos", force: :cascade do |t|
    t.text "caption"
    t.text "telegram_photo"
    t.integer "chat_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "member_id"
    t.integer "times_accessed", default: 0
    t.index ["chat_id"], name: "index_photos_on_chat_id"
    t.index ["member_id"], name: "index_photos_on_member_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.integer "chat_id"
    t.text "content", null: false
    t.text "context"
    t.string "author", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "longitude", precision: 12, scale: 7
    t.decimal "latitude", precision: 12, scale: 7
    t.boolean "location_confirmed", default: false
    t.integer "member_id"
    t.integer "times_accessed", default: 0
    t.index ["chat_id"], name: "index_quotes_on_chat_id"
    t.index ["member_id"], name: "index_quotes_on_member_id"
  end

  add_foreign_key "luck_histories", "members"
end
