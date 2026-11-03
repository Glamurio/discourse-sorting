# frozen_string_literal: true

class AddRateToDiscourseSortingDonations < ActiveRecord::Migration[7.2]
  def change
    # amount_cents stays in the currency the donor paid in. The thermometer adds up
    # (amount_cents - refunded_cents) * rate, where rate converts into the goal currency
    # (rate_currency). NULL until a rate could be fetched; a job fills those in.
    add_column :discourse_sorting_donations, :rate, :decimal, precision: 18, scale: 8
    add_column :discourse_sorting_donations, :rate_currency, :string, limit: 3
  end
end
