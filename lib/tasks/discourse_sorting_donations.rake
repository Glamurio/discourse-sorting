# frozen_string_literal: true

# Add a donation by hand, for example one received before the webhook existed:
#   rake "discourse_sorting:add_donation[5.00,USD]"
#   rake "discourse_sorting:add_donation[12,EUR,2026-10-28]"   (third argument: the date)
desc "Add a donation by hand: amount, currency, optional date"
task "discourse_sorting:add_donation", %i[amount currency date] => :environment do |_, args|
  currency = (args[:currency].presence || SiteSetting.discourse_sorting_donations_currency).upcase
  paid_at = args[:date].present? ? Time.zone.parse(args[:date]) : Time.now.utc
  abort "bad date" if paid_at.nil?

  donation =
    DiscourseSorting::Donation.record(
      external_id: "manual:#{SecureRandom.hex(6)}",
      kind: "manual",
      amount: args[:amount],
      currency: currency,
      paid_at: paid_at,
    )
  abort "could not add that donation (check the amount)" if donation.nil?

  puts "Added #{args[:amount]} #{currency} on #{paid_at.to_date}" \
         "#{donation.rate ? "" : " (no exchange rate yet, it will be converted within the hour)"}"
end
