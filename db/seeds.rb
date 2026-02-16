puts "🌱 Seeding AppartAgent..."

# Users
alice = User.create!(
  name: "Alice Dupont",
  email: "alice@exemple.fr",
  password: "password123",
  phone: "+33612345678",
  plan: "pro"
)

bob = User.create!(
  name: "Bob Martin",
  email: "bob@exemple.fr",
  password: "password123",
  phone: "+33698765432",
  plan: "free"
)

puts "✅ Users: #{User.count}"

# Search Profiles
sp1 = SearchProfile.create!(
  user: alice,
  city: "Paris",
  arrondissement: "11ème",
  min_budget: 800,
  max_budget: 1400,
  min_surface: 25,
  max_surface: 50,
  min_rooms: 1,
  max_rooms: 3,
  furnished: false,
  dpe_max: "D",
  property_type: "apartment",
  platforms_to_monitor: ["leboncoin", "seloger", "pap", "bienici"],
  active: true
)

sp2 = SearchProfile.create!(
  user: alice,
  city: "Paris",
  arrondissement: "Marais",
  min_budget: 1000,
  max_budget: 1800,
  min_surface: 30,
  max_surface: 60,
  min_rooms: 2,
  max_rooms: 3,
  furnished: true,
  property_type: "apartment",
  platforms_to_monitor: ["seloger", "bienici"],
  active: true
)

sp3 = SearchProfile.create!(
  user: bob,
  city: "Lyon",
  min_budget: 500,
  max_budget: 900,
  min_surface: 20,
  max_surface: 40,
  min_rooms: 1,
  max_rooms: 2,
  platforms_to_monitor: ["leboncoin", "pap"],
  active: true
)

puts "✅ Search Profiles: #{SearchProfile.count}"

# Listings
listings_data = [
  {
    platform: "leboncoin", external_id: "lbc_2847591", title: "Bel appartement T2 lumineux — Bastille",
    description: "Superbe T2 de 42m² au 3ème étage avec ascenseur. Parquet ancien, double vitrage, cuisine équipée. À 2 min du métro Bastille. Charges comprises.",
    price: 1150, surface: 42, rooms: 2, city: "Paris", postal_code: "75011",
    neighborhood: "Bastille", address: "15 rue de la Roquette", furnished: false,
    dpe_rating: "C", url: "https://www.leboncoin.fr/locations/2847591.htm",
    latitude: 48.8534, longitude: 2.3711, published_at: 2.hours.ago,
    photos: ["https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400"]
  },
  {
    platform: "seloger", external_id: "sl_189274", title: "Studio meublé Marais — Coup de cœur",
    description: "Charmant studio meublé de 28m² en plein cœur du Marais. Poutres apparentes, mezzanine. Proche métro Saint-Paul.",
    price: 980, surface: 28, rooms: 1, city: "Paris", postal_code: "75004",
    neighborhood: "Marais", address: "8 rue des Rosiers", furnished: true,
    dpe_rating: "D", url: "https://www.seloger.com/annonces/189274",
    latitude: 48.8566, longitude: 2.3522, published_at: 5.hours.ago,
    photos: ["https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=400"]
  },
  {
    platform: "pap", external_id: "pap_445821", title: "T3 rénové Montmartre — Vue dégagée",
    description: "Magnifique T3 de 65m² entièrement rénové. Vue sur les toits de Paris. 2 chambres, séjour lumineux, cuisine ouverte. Cave. Gardien.",
    price: 1650, surface: 65, rooms: 3, city: "Paris", postal_code: "75018",
    neighborhood: "Montmartre", address: "22 rue Lepic", furnished: false,
    dpe_rating: "B", url: "https://www.pap.fr/annonces/445821",
    latitude: 48.8847, longitude: 2.3325, published_at: 1.day.ago,
    photos: ["https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400"]
  },
  {
    platform: "bienici", external_id: "bi_773291", title: "T2 calme République — Idéal couple",
    description: "Bel appartement T2 de 38m² au calme sur cour. Séjour, chambre séparée, salle d'eau. Métro République à 3 min.",
    price: 1080, surface: 38, rooms: 2, city: "Paris", postal_code: "75010",
    neighborhood: "République", address: "5 passage du Buisson Saint-Louis", furnished: false,
    dpe_rating: "C", url: "https://www.bien-ici.com/annonce/773291",
    latitude: 48.8682, longitude: 2.3632, published_at: 8.hours.ago
  },
  {
    platform: "leboncoin", external_id: "lbc_2851034", title: "Grand T3 Oberkampf — Terrasse privative",
    description: "Exceptionnel T3 de 72m² avec terrasse de 15m². 2 chambres, double séjour, cuisine séparée équipée. DPE A, immeuble récent.",
    price: 1890, surface: 72, rooms: 3, city: "Paris", postal_code: "75011",
    neighborhood: "Oberkampf", address: "41 rue Oberkampf", furnished: false,
    dpe_rating: "A", url: "https://www.leboncoin.fr/locations/2851034.htm",
    latitude: 48.8649, longitude: 2.3682, published_at: 30.minutes.ago,
    photos: ["https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=400"]
  },
  {
    platform: "seloger", external_id: "sl_192847", title: "Studio étudiant Nation — Petit prix",
    description: "Studio fonctionnel de 18m² idéal étudiant. Kitchenette, salle d'eau, rangements. Proche Nation et universités.",
    price: 650, surface: 18, rooms: 1, city: "Paris", postal_code: "75012",
    neighborhood: "Nation", address: "12 rue de Picpus", furnished: true,
    dpe_rating: "E", url: "https://www.seloger.com/annonces/192847",
    latitude: 48.8462, longitude: 2.3958, published_at: 3.hours.ago
  },
  {
    platform: "pap", external_id: "pap_448192", title: "T2 charme Saint-Germain — Dernier étage",
    description: "Superbe T2 sous les toits de 35m² avec poutres. Vue sur les toits. Dernier étage sans ascenseur (5ème). Quartier très recherché.",
    price: 1320, surface: 35, rooms: 2, city: "Paris", postal_code: "75006",
    neighborhood: "Saint-Germain-des-Prés", address: "18 rue de Seine", furnished: false,
    dpe_rating: "D", url: "https://www.pap.fr/annonces/448192",
    latitude: 48.8546, longitude: 2.3372, published_at: 2.days.ago,
    photos: ["https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400"]
  },
  {
    platform: "leboncoin", external_id: "lbc_2849123", title: "T4 familial Belleville — Lumineux",
    description: "Bel appartement familial T4 de 85m². 3 chambres, séjour double, cuisine aménagée, balcon. École et parc à proximité.",
    price: 1750, surface: 85, rooms: 4, city: "Paris", postal_code: "75020",
    neighborhood: "Belleville", address: "30 rue de Belleville", furnished: false,
    dpe_rating: "C", url: "https://www.leboncoin.fr/locations/2849123.htm",
    latitude: 48.8714, longitude: 2.3849, published_at: 6.hours.ago
  },
  {
    platform: "bienici", external_id: "bi_778432", title: "Studio meublé Batignolles — Cosy",
    description: "Joli studio meublé de 22m² dans le village des Batignolles. Coin nuit, kitchenette équipée. Calme, sur cour arborée.",
    price: 820, surface: 22, rooms: 1, city: "Paris", postal_code: "75017",
    neighborhood: "Batignolles", address: "7 rue des Batignolles", furnished: true,
    dpe_rating: "D", url: "https://www.bien-ici.com/annonce/778432",
    latitude: 48.8837, longitude: 2.3213, published_at: 12.hours.ago
  },
  {
    platform: "leboncoin", external_id: "lbc_9912345", title: "T2 moderne Part-Dieu — Lyon 3",
    description: "Appartement T2 récent de 45m², 4ème étage avec ascenseur. Balcon, parking en option. Proche gare Part-Dieu et commerces.",
    price: 780, surface: 45, rooms: 2, city: "Lyon", postal_code: "69003",
    neighborhood: "Part-Dieu", address: "10 rue Servient", furnished: false,
    dpe_rating: "B", url: "https://www.leboncoin.fr/locations/9912345.htm",
    latitude: 45.7602, longitude: 4.8575, published_at: 4.hours.ago
  },
  {
    platform: "pap", external_id: "pap_551234", title: "Studio Lyon Presqu'île — Centre ville",
    description: "Studio de 25m² en plein centre de Lyon, Presqu'île. Idéalement situé entre Bellecour et Perrache. Parquet, hauteur sous plafond.",
    price: 580, surface: 25, rooms: 1, city: "Lyon", postal_code: "69002",
    neighborhood: "Presqu'île", address: "4 rue Victor Hugo", furnished: false,
    dpe_rating: "C", url: "https://www.pap.fr/annonces/551234",
    latitude: 45.7554, longitude: 4.8324, published_at: 1.day.ago
  }
]

listings_data.each do |data|
  Listing.create!(data)
end

puts "✅ Listings: #{Listing.count}"

# Score all listings
Listing.find_each do |listing|
  listing.update!(score: ListingScorer.new(listing).score)
end

puts "✅ Listings scored"

# Alerts
listings = Listing.where(city: "Paris").limit(5)
listings.each do |listing|
  Alert.create!(
    user: alice,
    search_profile: sp1,
    listing: listing,
    channel: "email",
    sent_at: listing.published_at + 5.minutes
  )
end

Alert.last(2).each { |a| a.update!(seen_at: Time.current) }

puts "✅ Alerts: #{Alert.count}"

# Application Templates
ApplicationTemplate.create!(
  user: alice,
  name: "Candidature standard",
  content: <<~MSG
    Bonjour,

    Je me permets de vous contacter au sujet de votre annonce pour le logement situé au {adresse}, dans le quartier {quartier}.

    Je suis très intéressé(e) par ce bien proposé à {prix}€/mois. Je suis {nom}, actuellement en CDI, et je recherche activement un logement dans ce secteur.

    Je dispose de revenus stables (3x le loyer) et peux fournir un dossier complet (fiches de paie, avis d'imposition, pièce d'identité).

    Serait-il possible d'organiser une visite rapidement ?

    Bien cordialement,
    {nom}
    Date : {date}
  MSG
)

ApplicationTemplate.create!(
  user: alice,
  name: "Candidature courte",
  content: <<~MSG
    Bonjour,

    Votre annonce au {adresse} ({prix}€/mois, {surface}m²) m'intéresse beaucoup. Dossier solide et disponible pour une visite immédiate.

    Cordialement,
    {nom}
  MSG
)

puts "✅ Templates: #{ApplicationTemplate.count}"
puts "🎉 Seeding complete!"
