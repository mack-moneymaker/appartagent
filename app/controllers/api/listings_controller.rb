module Api
  class ListingsController < BaseController
    # POST /api/listings/import
    def import
      listings_data = params.require(:listings)
      created = 0
      updated = 0
      errors = []

      listings_data.each do |listing_params|
        listing = Listing.find_or_initialize_by(
          platform: listing_params[:platform],
          external_id: listing_params[:external_id]
        )

        was_new = listing.new_record?

        listing.assign_attributes(
          title: listing_params[:title],
          price: listing_params[:price],
          city: listing_params[:city],
          postal_code: listing_params[:postal_code],
          address: listing_params[:address],
          surface: listing_params[:surface],
          rooms: listing_params[:rooms],
          url: listing_params[:url],
          photos: listing_params[:photos],
          description: listing_params[:description],
          furnished: listing_params[:furnished],
          published_at: listing_params[:published_at] || Time.current
        )

        if listing.save
          was_new ? created += 1 : updated += 1

          # Check against active search profiles and create alerts for new listings
          if was_new
            SearchProfile.where(active: true).find_each do |profile|
              next unless profile.platforms.include?(listing.platform)
              next unless profile.matches_listing?(listing)

              Alert.create(
                user: profile.user,
                search_profile: profile,
                listing: listing,
                channel: "web"
              )
            end
          end
        else
          errors << { external_id: listing_params[:external_id], errors: listing.errors.full_messages }
        end
      end

      render json: { created: created, updated: updated, errors: errors }
    end
  end
end
