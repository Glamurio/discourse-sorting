# frozen_string_literal: true

class CreateDiscourseSortingDonations < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_sorting_donations do |t|
      # PayPal's id of the payment (sale or capture); makes webhook retries harmless
      t.string :paypal_id, null: false
      t.string :kind, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, limit: 3, null: false
      t.bigint :refunded_cents, null: false, default: 0
      t.datetime :paid_at, null: false
      t.timestamps
    end

    add_index :discourse_sorting_donations, :paypal_id, unique: true
    add_index :discourse_sorting_donations, :paid_at
  end
end
