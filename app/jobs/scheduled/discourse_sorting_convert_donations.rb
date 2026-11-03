# frozen_string_literal: true

module Jobs
  # Gives payments in other currencies a rate into the goal currency when the lookup
  # failed at the time (the ECB rate service was unreachable).
  class DiscourseSortingConvertDonations < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return if !SiteSetting.discourse_sorting_enabled
      return if !SiteSetting.discourse_sorting_donations_enabled

      DiscourseSorting::Donation.convert_pending!
    end
  end
end
