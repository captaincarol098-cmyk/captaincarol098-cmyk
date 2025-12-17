class DateVariety {
  final String name;
  final String description;
  final String fullDescription;
  final String imagePath;
  final List<String> characteristics;
  final String origin;
  final String season;
  final String nutritionalInfo;
  final String healthBenefits;
  final String culinaryUses;
  final String storageTips;

  const DateVariety({
    required this.name,
    required this.description,
    required this.fullDescription,
    required this.imagePath,
    required this.characteristics,
    required this.origin,
    required this.season,
    required this.nutritionalInfo,
    required this.healthBenefits,
    required this.culinaryUses,
    required this.storageTips,
  });

  static const List<DateVariety> allVarieties = [
    DateVariety(
      name: 'Sagai Dates',
      description: 'Medium-sized dates with golden-brown color and soft texture.',
      fullDescription: 'Sagai dates are premium Saudi dates renowned for their perfect balance of sweetness and texture. These medium-sized dates feature a beautiful golden-brown exterior that transitions to a soft, tender interior. Cultivated primarily in the Al-Kharj region, Sagai dates represent the excellence of Saudi date farming traditions. Their delicate flavor profile makes them highly sought after by date connoisseurs worldwide.',
      imagePath: 'assets/class Image/sagai.jpg',
      characteristics: ['Golden-brown color', 'Soft texture', 'Sweet taste', 'Medium size'],
      origin: 'Al-Kharj region, Saudi Arabia',
      season: 'September - October',
      nutritionalInfo: 'Rich in natural sugars, fiber, potassium, magnesium, and vitamin B6. Approximately 277 calories per 100g serving.',
      healthBenefits: 'Provides quick energy, supports digestive health, helps maintain healthy blood pressure, and supports bone health.',
      culinaryUses: 'Perfect for snacking, baking, stuffing with nuts, or serving with Arabic coffee. Ideal for breaking fast during Ramadan.',
      storageTips: 'Store in airtight container at room temperature for up to 6 months, or refrigerate for extended freshness.',
    ),
    DateVariety(
      name: 'Amber Dates',
      description: 'Large, amber-colored dates with firm flesh and rich, honey-like sweetness.',
      fullDescription: 'Amber dates are among the most luxurious date varieties, distinguished by their large size and stunning amber coloration. These premium dates from Madinah boast a firm, meaty texture that provides a satisfying chew. Their honey-like sweetness is more refined than other varieties, making them perfect for those who prefer sophisticated flavors. Amber dates represent the pinnacle of Saudi date cultivation excellence.',
      imagePath: 'assets/class Image/Amber .png',
      characteristics: ['Amber color', 'Large size', 'Firm flesh', 'Honey-like sweetness'],
      origin: 'Madinah region, Saudi Arabia',
      season: 'August - September',
      nutritionalInfo: 'High in natural sugars, dietary fiber, antioxidants, and essential minerals including iron and calcium.',
      healthBenefits: 'Boosts energy levels, supports immune function, promotes healthy skin, and aids in muscle function.',
      culinaryUses: 'Excellent for gourmet presentations, stuffing with almonds, or serving as premium gifts. Perfect for special occasions.',
      storageTips: 'Keep in cool, dry place. Can be stored for up to a year when properly sealed and kept away from moisture.',
    ),
    DateVariety(
      name: 'Sukkari Dates',
      description: 'Often called "sugar dates" for their exceptional sweetness.',
      fullDescription: 'Sukkari dates, meaning "sugar dates" in Arabic, are the sweetest variety available. These golden gems from Qassim region are famous for their melt-in-mouth texture that dissolves effortlessly. Their intense sweetness is balanced by a delicate flavor that makes them irresistible. Sukkari dates are traditionally served to honored guests and are considered a symbol of hospitality in Saudi culture.',
      imagePath: 'assets/class Image/sukkari.jpg',
      characteristics: ['Extremely sweet', 'Soft texture', 'Golden color', 'Melts in mouth'],
      origin: 'Qassim region, Saudi Arabia',
      season: 'August - October',
      nutritionalInfo: 'Contains high levels of natural glucose, fructose, dietary fiber, and essential vitamins including A and K.',
      healthBenefits: 'Provides immediate energy boost, supports digestive health, promotes healthy vision, and aids in blood clotting.',
      culinaryUses: 'Perfect for natural sweetening in recipes, making date syrup, or enjoying as a luxurious treat. Great for energy bars.',
      storageTips: 'Best consumed fresh but can be frozen for up to 2 years. Keep in sealed container to prevent drying.',
    ),
    DateVariety(
      name: 'Barhi Dates',
      description: 'Unique dates that can be eaten fresh (yellow and crunchy) or ripe (brown and soft).',
      fullDescription: 'Barhi dates are unique among date varieties as they offer two completely different taste experiences depending on ripeness. When fresh and yellow, they provide a crunchy, apple-like texture with mild sweetness. When fully ripened to brown, they transform into soft, sweet dates. Originally from Iraq but now successfully cultivated in Saudi Arabia, Barhi dates showcase the versatility of date fruits.',
      imagePath: 'assets/class Image/Barhi.jpg',
      characteristics: ['Can eat fresh or ripe', 'Crunchy when fresh', 'Mild flavor', 'Versatile'],
      origin: 'Iraq, now grown in Saudi Arabia',
      season: 'September - November',
      nutritionalInfo: 'Rich in dietary fiber, vitamin C (when fresh), potassium, and natural sugars. Low glycemic index when ripe.',
      healthBenefits: 'Supports digestive health, boosts immunity (fresh), regulates blood sugar, and promotes heart health.',
      culinaryUses: 'Fresh Barhi can be used in salads, ripe ones for baking. Perfect for date milkshakes and smoothies.',
      storageTips: 'Fresh Barhi requires refrigeration and should be consumed within weeks. Ripe ones last longer at room temperature.',
    ),
    DateVariety(
      name: 'Mabroom Dates',
      description: 'Long, slender dates with reddish-brown skin and firm texture.',
      fullDescription: 'Mabroom dates are distinguished by their elegant elongated shape and reddish-brown appearance. These premium dates from Madinah feature a firm texture that provides a satisfying chew. Their distinctive appearance makes them easily recognizable among date varieties. Mabroom dates are prized for their consistent quality and are often used in traditional Saudi hospitality.',
      imagePath: 'assets/class Image/mabroom.png',
      characteristics: ['Elongated shape', 'Reddish-brown skin', 'Firm texture', 'Distinctive appearance'],
      origin: 'Madinah region, Saudi Arabia',
      season: 'August - September',
      nutritionalInfo: 'Excellent source of dietary fiber, iron, magnesium, and B vitamins. Contains natural antioxidants.',
      healthBenefits: 'Supports digestive health, prevents anemia, promotes muscle function, and supports energy metabolism.',
      culinaryUses: 'Perfect for stuffing with walnuts, serving with tea, or using in traditional Saudi desserts.',
      storageTips: 'Store in cool, dry place. Maintains quality for up to 8 months when properly stored.',
    ),
    DateVariety(
      name: 'Safawi Dates',
      description: 'Dark-colored dates with soft flesh and rich, sweet flavor.',
      fullDescription: 'Safawi dates are among the most popular dark date varieties from Madinah. These dates feature a distinctive dark coloration and soft, tender flesh that melts in your mouth. Their rich, complex sweetness makes them a favorite among date enthusiasts. Safawi dates are traditionally used during Ramadan and are known for their consistent quality and superior taste.',
      imagePath: 'assets/class Image/Safawi.jpeg',
      characteristics: ['Dark color', 'Soft flesh', 'Rich flavor', 'Wrinkled skin'],
      origin: 'Madinah region, Saudi Arabia',
      season: 'August - September',
      nutritionalInfo: 'High in natural sugars, dietary fiber, potassium, and contains beneficial antioxidants including flavonoids.',
      healthBenefits: 'Provides sustained energy, supports heart health, aids in digestion, and has anti-inflammatory properties.',
      culinaryUses: 'Ideal for breaking fast, making date paste, or enjoying with Arabic coffee. Great for energy balls.',
      storageTips: 'Best stored in airtight container. Can be refrigerated for up to 12 months without losing quality.',
    ),
    DateVariety(
      name: 'Zahidi Dates',
      description: 'Large, oval-shaped dates with golden-yellow color and firm texture.',
      fullDescription: 'Zahidi dates are characterized by their impressive size and beautiful golden-yellow color. Originally from Iraq but now extensively cultivated in Saudi Arabia, these dates offer a milder sweetness compared to other varieties. Their firm texture and large size make them perfect for stuffing and culinary applications. Zahidi dates are versatile and widely used in both traditional and modern date preparations.',
      imagePath: 'assets/class Image/zahidi.jpg',
      characteristics: ['Large size', 'Oval shape', 'Golden-yellow', 'Firm texture'],
      origin: 'Iraq, now grown in Saudi Arabia',
      season: 'September - October',
      nutritionalInfo: 'Good source of dietary fiber, copper, magnesium, and vitamin B6. Moderate sugar content.',
      healthBenefits: 'Supports nervous system health, aids in energy production, supports bone health, and promotes digestion.',
      culinaryUses: 'Excellent for stuffing with nuts, chopping into salads, or using in baked goods. Perfect for date bread.',
      storageTips: 'Stores well at room temperature for up to 6 months. Firm texture helps maintain quality during storage.',
    ),
    DateVariety(
      name: 'Helwa Dates',
      description: 'Translucent dates with soft texture and delicate sweetness.',
      fullDescription: 'Helwa dates, meaning "sweet" in Arabic, live up to their name with their delicate sweetness and unique translucent appearance. These light-colored dates from Saudi Arabia\'s Eastern Province offer a refined sweetness that appeals to those who prefer subtler flavors. Their soft texture and beautiful appearance make them perfect for elegant presentations and special occasions.',
      imagePath: 'assets/class Image/Helwa.jpeg',
      characteristics: ['Translucent appearance', 'Soft texture', 'Delicate sweetness', 'Light colored'],
      origin: 'Eastern Province, Saudi Arabia',
      season: 'August - September',
      nutritionalInfo: 'Contains natural sugars, dietary fiber, vitamin C, and essential minerals including calcium and iron.',
      healthBenefits: 'Supports immune function, promotes bone health, aids in digestion, and provides gentle energy.',
      culinaryUses: 'Perfect for elegant desserts, serving with tea, or using in sophisticated date preparations.',
      storageTips: 'Requires careful storage in cool, dry place. Best consumed within 6 months for optimal quality.',
    ),
    DateVariety(
      name: 'Ajwa Dates',
      description: 'Holy dates from Madinah with dark color and soft texture.',
      fullDescription: 'Ajwa dates hold a special place in Islamic tradition as they are cultivated in the blessed region of Madinah. These dark, soft dates are considered the finest and most spiritually significant variety. Prophet Muhammad (peace be upon him) specifically mentioned Ajwa dates for their healing properties. Their rarity and spiritual significance make them highly prized among Muslims worldwide.',
      imagePath: 'assets/class Image/ajwa.png',
      characteristics: ['Dark color', 'Soft texture', 'Premium quality', 'Spiritual significance'],
      origin: 'Madinah, Saudi Arabia',
      season: 'August - September',
      nutritionalInfo: 'Rich in antioxidants, dietary fiber, potassium, and contains unique phytonutrients. Low glycemic index.',
      healthBenefits: 'Traditionally believed to have healing properties, supports heart health, provides protection against toxins, and boosts immunity.',
      culinaryUses: 'Traditionally eaten in pairs, used in traditional medicine, or served during special religious occasions.',
      storageTips: 'Precious and should be stored carefully. Can be refrigerated for up to a year while maintaining medicinal properties.',
    ),
    DateVariety(
      name: 'Mazafati Dates',
      description: 'Dark, soft dates with high moisture content.',
      fullDescription: 'Mazafati dates are known for their exceptionally soft texture and high moisture content, giving them a fresh, tender quality. While originally from Iran, they are now successfully cultivated in Saudi Arabia. These dark dates have a rich, fresh taste that appeals to those who prefer less intense sweetness. Their tender texture makes them perfect for various culinary applications.',
      imagePath: 'assets/class Image/Mazafati.jpeg',
      characteristics: ['Dark color', 'High moisture', 'Fresh taste', 'Tender texture'],
      origin: 'Iran, also grown in Saudi Arabia',
      season: 'September - October',
      nutritionalInfo: 'High moisture content, rich in dietary fiber, natural sugars, and contains vitamin B complex.',
      healthBenefits: 'Provides gentle hydration, supports digestive health, offers sustained energy, and promotes skin health.',
      culinaryUses: 'Perfect for date milk, smoothies, or fresh eating. Great for date-based desserts and sauces.',
      storageTips: 'Requires refrigeration due to high moisture content. Best consumed within 3-4 months for optimal freshness.',
    ),
  ];

  static DateVariety? findByName(String name) {
    final cleanName = name.trim().toLowerCase();
    return allVarieties.firstWhere(
      (variety) => variety.name.toLowerCase().contains(cleanName) ||
                   cleanName.contains(variety.name.split(' ').first.toLowerCase()),
      orElse: () => allVarieties.first, // Default fallback
    );
  }
}