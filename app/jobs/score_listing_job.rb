class ScoreListingJob < ApplicationJob
  queue_as :default

  def perform(listing_id)
    listing = Listing.find(listing_id)
    scorer = ListingScorer.new(listing)
    listing.update!(score: scorer.score)
  end
end
