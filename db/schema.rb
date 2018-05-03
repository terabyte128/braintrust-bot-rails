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

ActiveRecord::Schema.define(version: 20180503055633) do

  create_table "chats", force: :cascade do |t|
    t.string "telegram_id", null: false
    t.boolean "quotes_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "quotes", force: :cascade do |t|
    t.integer "chat_id_id"
    t.text "content", null: false
    t.text "context"
    t.string "author", null: false
    t.string "sender"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "longitude", precision: 12, scale: 7
    t.decimal "latitude", precision: 12, scale: 7
    t.index ["chat_id_id"], name: "index_quotes_on_chat_id_id"
  end

end
