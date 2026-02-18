# frozen_string_literal: true

puts "🌱 Seeding AppartAgent demo data..."

# Clean existing demo data
User.find_by(email: "demo@appartagent.fr")&.destroy

# Demo user
user = User.create!(
  name: "Marie Dupont",
  email: "demo@appartagent.fr",
  password: "password123",
  plan: "pro",
  phone: "+33612345678"
)
puts "✅ Created demo user: #{user.email}"

# Search profiles
paris = SearchProfile.create!(
  user: user,
  city: "Paris",
  arrondissement: "75011",
  min_budget: 800,
  max_budget: 1500,
  min_surface: 25,
  max_surface: 60,
  min_rooms: 1,
  max_rooms: 3,
  property_type: "apartment",
  furnished: false,
  platforms_to_monitor: %w[seloger leboncoin pap bienici].to_json,
  active: true
)

lyon = SearchProfile.create!(
  user: user,
  city: "Lyon",
  arrondissement: "69003",
  min_budget: 500,
  max_budget: 1000,
  min_surface: 30,
  max_surface: 70,
  min_rooms: 2,
  max_rooms: 4,
  property_type: "apartment",
  furnished: true,
  platforms_to_monitor: %w[seloger leboncoin pap].to_json,
  active: true
)
puts "✅ Created 2 search profiles"

# Listings
listings_data = [
  { platform: "pap", external_id: "pap-101", title: "Bel appartement lumineux Bastille", price: 1200, surface: 42, rooms: 2,
    city: "Paris", postal_code: "75011", neighborhood: "Bastille", dpe_rating: "C", furnished: false,
    description: "Magnifique 2 pièces au 3ème étage, parquet ancien, double vitrage. Proche métro Bastille. Cuisine équipée, salle de bain refaite.",
    photos: ["https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800"], address: "15 rue de la Roquette",
    latitude: 48.8534, longitude: 2.3716, published_at: 2.hours.ago },
  { platform: "seloger", external_id: "sel-202", title: "Studio rénové République", price: 890, surface: 22, rooms: 1,
    city: "Paris", postal_code: "75011", neighborhood: "République", dpe_rating: "D", furnished: false,
    description: "Studio entièrement rénové, idéal premier appartement. Kitchenette équipée, douche italienne.",
    photos: ["https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800"], address: "8 rue Oberkampf",
    latitude: 48.8648, longitude: 2.3682, published_at: 5.hours.ago },
  { platform: "leboncoin", external_id: "lbc-303", title: "3 pièces charme Charonne", price: 1450, surface: 55, rooms: 3,
    city: "Paris", postal_code: "75011", neighborhood: "Charonne", dpe_rating: "B", furnished: false,
    description: "Superbe 3 pièces traversant, poutres apparentes, cheminée décorative. 2 chambres, séjour lumineux. Cave.",
    photos: ["https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800"], address: "42 rue de Charonne",
    latitude: 48.8537, longitude: 2.3788, published_at: 1.day.ago },
  { platform: "bienici", external_id: "bi-404", title: "T2 moderne métro Voltaire", price: 1100, surface: 35, rooms: 2,
    city: "Paris", postal_code: "75011", neighborhood: "Voltaire", dpe_rating: "C", furnished: false,
    description: "Appartement refait à neuf, cuisine ouverte, chambre séparée. Gardien, digicode. 5min métro Voltaire.",
    photos: ["https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800"], address: "23 boulevard Voltaire",
    latitude: 48.8612, longitude: 2.3801, published_at: 12.hours.ago },
  { platform: "pap", external_id: "pap-505", title: "Grand studio Oberkampf", price: 950, surface: 28, rooms: 1,
    city: "Paris", postal_code: "75011", neighborhood: "Oberkampf", dpe_rating: "D", furnished: true,
    description: "Grand studio meublé avec mezzanine. Quartier vivant, nombreux commerces et restaurants.",
    photos: ["https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800"], address: "67 rue Oberkampf",
    latitude: 48.8657, longitude: 2.3719, published_at: 3.hours.ago },
  { platform: "seloger", external_id: "sel-606", title: "T4 familial Nation", price: 1800, surface: 75, rooms: 4,
    city: "Paris", postal_code: "75011", neighborhood: "Nation", dpe_rating: "B", furnished: false,
    description: "Bel appartement familial, 3 chambres, double séjour, balcon. Proche écoles et parc.",
    photos: ["https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800"], address: "5 place de la Nation",
    latitude: 48.8487, longitude: 2.3957, published_at: 2.days.ago },
  { platform: "leboncoin", external_id: "lbc-707", title: "2 pièces calme Père Lachaise", price: 1050, surface: 38, rooms: 2,
    city: "Paris", postal_code: "75011", neighborhood: "Père Lachaise", dpe_rating: "E", furnished: false,
    description: "Appartement au calme sur cour, lumineux, cuisine séparée équipée. Proche cimetière du Père Lachaise.",
    photos: ["https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=800"], address: "12 rue de la Folie Méricourt",
    latitude: 48.8608, longitude: 2.3843, published_at: 6.hours.ago },
  { platform: "pap", external_id: "pap-808", title: "Duplex atypique Ménilmontant", price: 1350, surface: 48, rooms: 2,
    city: "Paris", postal_code: "75020", neighborhood: "Ménilmontant", dpe_rating: "C", furnished: false,
    description: "Duplex de caractère sous les toits, vue dégagée sur Paris. Séjour avec verrière, chambre en mezzanine.",
    photos: ["https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800"], address: "89 rue de Ménilmontant",
    latitude: 48.8655, longitude: 2.3892, published_at: 8.hours.ago },
  # Lyon listings
  { platform: "pap", external_id: "pap-901", title: "T3 lumineux Part-Dieu", price: 850, surface: 58, rooms: 3,
    city: "Lyon", postal_code: "69003", neighborhood: "Part-Dieu", dpe_rating: "C", furnished: true,
    description: "Bel appartement meublé proche gare Part-Dieu. 2 chambres, séjour spacieux, cuisine équipée. Tramway au pied.",
    photos: ["https://images.unsplash.com/photo-1560185893-a55cbc8c57e8?w=800"], address: "18 rue de la Part-Dieu",
    latitude: 45.7607, longitude: 4.8592, published_at: 4.hours.ago },
  { platform: "seloger", external_id: "sel-902", title: "Studio charme Vieux Lyon", price: 620, surface: 24, rooms: 1,
    city: "Lyon", postal_code: "69005", neighborhood: "Vieux Lyon", dpe_rating: "D", furnished: true,
    description: "Charmant studio meublé dans le quartier historique. Poutres apparentes, pierres dorées. Métro Vieux Lyon.",
    photos: ["https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800"], address: "3 rue Saint-Jean",
    latitude: 45.7626, longitude: 4.8271, published_at: 1.day.ago },
  { platform: "leboncoin", external_id: "lbc-903", title: "T2 moderne Confluence", price: 780, surface: 40, rooms: 2,
    city: "Lyon", postal_code: "69002", neighborhood: "Confluence", dpe_rating: "A", furnished: true,
    description: "Appartement neuf dans l'écoquartier Confluence. Balcon, parking inclus. Bâtiment BBC.",
    photos: ["https://images.unsplash.com/photo-1502672023488-70e25813eb80?w=800"], address: "25 quai Perrache",
    latitude: 45.7419, longitude: 4.8182, published_at: 10.hours.ago },
  { platform: "bienici", external_id: "bi-904", title: "Grand T3 Croix-Rousse", price: 920, surface: 65, rooms: 3,
    city: "Lyon", postal_code: "69004", neighborhood: "Croix-Rousse", dpe_rating: "D", furnished: false,
    description: "Spacieux 3 pièces sur les pentes de la Croix-Rousse. Vue sur Fourvière, parquet, hauteur sous plafond.",
    photos: ["https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800"], address: "14 montée de la Grande Côte",
    latitude: 45.7725, longitude: 4.8314, published_at: 3.days.ago },
  { platform: "pap", external_id: "pap-905", title: "T2 rénové Guillotière", price: 680, surface: 36, rooms: 2,
    city: "Lyon", postal_code: "69007", neighborhood: "Guillotière", dpe_rating: "C", furnished: true,
    description: "2 pièces entièrement rénové, quartier cosmopolite et animé. Proche universités et transports.",
    photos: ["https://images.unsplash.com/photo-1560448075-bb7f751fc97d?w=800"], address: "45 rue de Marseille",
    latitude: 45.7528, longitude: 4.8419, published_at: 7.hours.ago },
  { platform: "seloger", external_id: "sel-906", title: "Studio étudiant Villeurbanne", price: 450, surface: 18, rooms: 1,
    city: "Lyon", postal_code: "69100", neighborhood: "Villeurbanne", dpe_rating: "E", furnished: true,
    description: "Petit studio meublé idéal étudiant. Campus universitaire à 5 min. Charges comprises.",
    photos: ["https://images.unsplash.com/photo-1560448204-603b3fc33ddc?w=800"], address: "2 avenue Einstein",
    latitude: 45.7818, longitude: 4.8792, published_at: 2.days.ago },
  { platform: "pap", external_id: "pap-907", title: "Loft atypique Gerland", price: 990, surface: 70, rooms: 3,
    city: "Lyon", postal_code: "69007", neighborhood: "Gerland", dpe_rating: "B", furnished: false,
    description: "Ancien atelier transformé en loft. Volumes exceptionnels, verrière industrielle. Quartier en pleine mutation.",
    photos: ["https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800"], address: "78 avenue Jean Jaurès",
    latitude: 45.7312, longitude: 4.8345, published_at: 14.hours.ago },
  { platform: "leboncoin", external_id: "lbc-908", title: "T2 cosy Monplaisir", price: 720, surface: 42, rooms: 2,
    city: "Lyon", postal_code: "69008", neighborhood: "Monplaisir", dpe_rating: "C", furnished: false,
    description: "Charmant 2 pièces dans le quartier Monplaisir-Lumière. Proche Institut Lumière, commerces, métro D.",
    photos: ["https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?w=800"], address: "33 rue du Premier Film",
    latitude: 45.7453, longitude: 4.8689, published_at: 18.hours.ago },
]

listings = listings_data.map do |data|
  listing = Listing.create!(data)
  # Compute score
  listing.update!(score: ListingScorer.new(listing).score)
  listing
end
puts "✅ Created #{listings.size} listings"

# Alerts (link some listings to the demo user's profiles)
alert_count = 0
listings.first(6).each do |listing|
  Alert.create!(user: user, search_profile: paris, listing: listing, channel: "email", sent_at: listing.published_at + 5.minutes)
  alert_count += 1
end
listings[8..13]&.each do |listing|
  Alert.create!(user: user, search_profile: lyon, listing: listing, channel: "email", sent_at: listing.published_at + 5.minutes)
  alert_count += 1
end
# A couple unseen ones
listings.last(3).each do |listing|
  Alert.create!(user: user, search_profile: lyon, listing: listing, channel: "email")
  alert_count += 1
end
puts "✅ Created #{alert_count} alerts"

# Application template
ApplicationTemplate.create!(
  user: user,
  name: "Candidature standard",
  content: <<~TEMPLATE
    Madame, Monsieur,

    Je me permets de vous contacter au sujet de votre annonce pour le logement situé au {adresse}, {quartier} — {surface} m² à {prix} €/mois.

    Je suis {nom}, actuellement en CDI. Je dispose de revenus stables et peux fournir l'ensemble des justificatifs requis (3 derniers bulletins de salaire, avis d'imposition, pièce d'identité).

    Je suis disponible pour une visite à votre convenance.

    Cordialement,
    {nom}
    Date : {date}
  TEMPLATE
)
puts "✅ Created application template"

puts "🎉 Seed complete! Login: demo@appartagent.fr / password123"
