# frozen_string_literal: true

# Discourse loads plugin task files twice (as a plugin and through the engine), which
# would register every task body twice and run it twice. Define each task only once.

unless Rake::Task.task_defined?("discourse_sorting:add_donation")
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
end

unless Rake::Task.task_defined?("discourse_sorting:donations")
  # List this month's payments with their ids (needed for the refund task):
  #   rake "discourse_sorting:donations"
  desc "List this month's donations"
  task "discourse_sorting:donations" => :environment do
    rows = DiscourseSorting::Donation.where(paid_at: DiscourseSorting::Donation.month_range).order(:paid_at)
    rows.each do |d|
      refund = d.refunded_cents > 0 ? "  (refunded #{format("%.2f", d.refunded_cents / 100.0)})" : ""
      puts "#{d.paid_at.utc.strftime("%Y-%m-%d %H:%M")}  #{format("%8.2f", d.amount_cents / 100.0)} #{d.currency}  #{d.paypal_id}#{refund}"
    end
    puts "#{rows.size} payments; counted so far: #{format("%.2f", DiscourseSorting::Donation.raised_cents / 100.0)} #{DiscourseSorting::Donation.goal_currency}"
  end
end

unless Rake::Task.task_defined?("discourse_sorting:refund")
  # Mark a payment as refunded, wholly or in part (Ko-fi sends no refund events):
  #   rake "discourse_sorting:refund[kofi:abc123]"          the whole payment
  #   rake "discourse_sorting:refund[kofi:abc123,2.50]"     part of it, in the payment's own currency
  desc "Refund a donation: id, optional amount"
  task "discourse_sorting:refund", %i[id amount] => :environment do |_, args|
    donation = DiscourseSorting::Donation.find_by(paypal_id: args[:id])
    abort "no donation with id #{args[:id].inspect} (see rake discourse_sorting:donations)" if donation.nil?

    cents = args[:amount].present? ? DiscourseSorting::Donation.to_cents(args[:amount]) : donation.amount_cents
    donation.update!(refunded_cents: [cents, donation.amount_cents].min)
    Discourse.cache.delete("discourse_sorting:donations")
    puts "#{donation.paypal_id} now refunded #{format("%.2f", donation.refunded_cents / 100.0)} of #{format("%.2f", donation.amount_cents / 100.0)} #{donation.currency}"
  end
end
