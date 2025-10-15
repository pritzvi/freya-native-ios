import { fcSearch } from "./firecrawl.js";

// Sephora allowlist - brands available at Sephora
const SEPHORA_BRANDS = [
  "AAVRANI", "ABBOTT", "Act+Acre", "adwoa beauty", "AERIN", "AESTURA", "ALPYN", "ALTERNA Haircare", 
  "Ami Colé", "amika", "Anastasia Beverly Hills", "Aquis", "Ariana Grande", "Armani Beauty", 
  "Artist Couture", "Augustinus Bader", "Azzaro", "BaBylissPRO", "banu", "bareMinerals", "BASMA", 
  "Beauty of Joseon", "BeautyBio", "Beautyblender", "belif", "Benefit Cosmetics", "Bio Ionic", 
  "Biodance", "Biossance", "Blinc", "Bobbi Brown", "BondiBoost", "Boy Smells", "BREAD BEAUTY SUPPLY", 
  "Briogeo", "BROWN GIRL Jane", "Bumble and bumble", "BURBERRY", "By Rosie Jane", "caliray", 
  "CANOPY", "Carolina Herrera", "Caudalie", "CAY SKIN", "Ceremonia", "CHANEL", "Charlotte Tilbury", 
  "Chloé", "Chris McMillan", "Chunks", "ciele", "Cinema Secrets", "Clarins", "CLEAN RESERVE", 
  "CLINIQUE", "COLOR WOW", "Commodity", "Community Sixty-Six", "COOLA", "Crown Affair", "Curlsmith", 
  "dae", "DAMDAM", "Danessa Myricks Beauty", "Davines", "DedCool", "DEREK LAM 10 CROSBY", "DERMAFLASH", 
  "Dermalogica", "Dezi Skin", "Dieux", "DIOR", "Dolce&Gabbana", "DOMINIQUE COSMETICS", "Donna Karan", 
  "Dr. Barbara Sturm", "Dr. Dennis Gross Skincare", "Dr. Idriss", "Dr. Jart+", "Drunk Elephant", 
  "Drybar", "DUO", "Dyson", "EADEM", "Element Eight", "Elemis", "Ellis Brooklyn", "Emi Jay", 
  "Estée Lauder", "Experiment", "Fable & Mane", "FaceGym", "Facile", "Fara Homidi", "Farmacy", 
  "Fashion Fair", "Fenty Beauty by Rihanna", "First Aid Beauty", "Flora + Bast", "Floral Street", 
  "FOREO", "FORVR Mood", "Freck Beauty", "fresh", "Function of Beauty PRO", "ghd", "Gisou", "Givenchy", 
  "Glamnetic", "Glossier", "Glow Recipe", "goop", "Grande Cosmetics", "Gucci", "GUERLAIN", 
  "GXVE BY GWEN STEFANI", "Hanni", "Hanyul", "Harlem Perfume Co.", "HAUS LABS BY LADY GAGA", 
  "Hello Sunday", "Henry Rose", "Herbivore", "HERMÈS", "HigherDOSE", "Hourglass", "House of Lashes", 
  "HUDA BEAUTY", "Hugo Boss", "HUNG VANNGO BEAUTY", "Hyper Skin", "Iconic London", "IGK", "ILIA", 
  "The INKEY List", "INNBEAUTY Project", "innisfree", "Iris&Romeo", "ISAMAYA", "ISDIN", 
  "Isle of Paradise", "IT Cosmetics", "Jack Black", "Jean Paul Gaultier", "JIMMY CHOO", 
  "Jo Malone London", "Josie Maran", "Juicy Couture", "Juliette Has a Gun", "JVN", 
  "K18 Biomimetic Hairscience", "Kaja", "Kate McLeod", "Kate Somerville", "Katini Skin", "KAYALI", 
  "Kérastase", "Kiehl's Since 1851", "KILIAN Paris", "KORA Organics", "KORRES", "Kosas", "Kulfi", 
  "KVD Beauty", "L'Occitane", "L'Oréal Professionnel", "L'Oréal Professionnel Steampod", "La Mer", 
  "Lancôme", "LANEIGE", "Laura Mercier", "LAWLESS", "LIGHTSAVER", "Lilly Lashes", "Lion Pose", 
  "Living Proof", "LORE", "LoveShackFancy", "Luna Daily", "Lux Unfiltered", "LYS Beauty", 
  "m.ph by Mary Phillips", "MACRENE actives", "MAED", "Maison Louis Marie", "Maison Margiela", 
  "MAKE UP FOR EVER", "The Maker", "MAKEUP BY MARIO", "Mane", "Mango People", "manucurist", "MARA", 
  "Marc Jacobs Fragrances", "Mario Badescu", "MATTER OF FACT", "maude", "Melanin Haircare", 
  "Melt Cosmetics", "MERIT", "Messy by Alli Webb", "Milk Makeup", "Miu Miu", "Mizani", "Montale", 
  "Montblanc", "Moon Juice", "Moroccanoil", "Mugler", "Murad", "NARS", "NATASHA DENONA", 
  "Naturally Serious", "Nécessaire", "NEST New York", "Nette", "NUDESTIX", "The Nue Co.", "NuFACE", 
  "Nutrafol", "Olaplex", "OLEHENRIKSEN", "ONE/SIZE by Patrick Starrr", "The Ordinary", "Oribe", 
  "The Original MakeUp Eraser", "Origins", "OUAI", "OUI the People", "The Outset", "PAT McGRATH LABS", 
  "PATRICK TA", "PATTERN by Tracee Ellis Ross", "Paula's Choice", "Peace Out", "Peter Thomas Roth", 
  "PHLUR", "PHYLA", "Prada", "Prada Beauty", "Pureology", "Rabanne", "Rahua", "Ralph Lauren", 
  "RANAVAT", "Range Beauty", "Rare Beauty by Selena Gomez", "REFY", "rhode", "RIES", "ROSE INC", 
  "ROSE Ingleton MD", "Rosebud Perfume Co.", "Rossano Ferretti Parma", "RŌZ", "Saie", "Saint Jane", 
  "Salt & Stone", "Sarah Creal", "SEPHORA COLLECTION", "Sephora Favorites", "SEPHORA The Merch Shop", 
  "Shani Darden Skin Care", "Shark Beauty", "SHAZ & KIKS", "Shiseido", "shu uemura", "Sienna Naturals", 
  "SIMIHAZE BEAUTY", "Sincerely Yours", "SK-II", "Skinfix", "Skylar", "Slip", "Smile Makers", 
  "SOFIE PAVITT FACE", "Soft Services", "Sol de Janeiro", "Soleil Toujours", "St. Tropez", "stila", 
  "Stripes", "StriVectin", "Sulwhasoo", "Summer Fridays", "SUNDAY II SUNDAY", "Sunday Riley", 
  "Supergoop!", "superzero", "Susteau", "T3", "Tabu", "TAN-LUXE", "tarte", "Tata Harper", "Tatcha", 
  "Then I Met You", "Therabody", "TOM FORD", "Too Faced", "Topicals", "Torriden", "Touchland", 
  "Tower 28 Beauty", "TULA Skincare", "TWEEZERMAN", "Ultra Violette", "Urban Decay", "Valentino", 
  "Vegamour", "Velour Lashes", "Verb", "Versace", "Viktor&Rolf", "VIOLETTE_FR", "Viori", "Virtue", 
  "Viseart", "VOLUSPA", "Wander Beauty", "Westman Atelier", "Wonderskin", "World of Chris Collins", 
  "Youth To The People", "YSE Beauty", "Yves Saint Laurent", "5 SENS", "54 Thrones", "The 7 Virtues"
];

// Normalize brand name for comparison (lowercase, remove punctuation/spaces)
function normalizeBrand(brand: string): string {
  return brand.toLowerCase().replace(/[^a-z0-9]/g, "");
}

// Check if product query contains a Sephora brand
function isSephoraBrand(productQuery: string): boolean {
  const normalizedQuery = normalizeBrand(productQuery);
  
  for (const brand of SEPHORA_BRANDS) {
    const normalizedBrand = normalizeBrand(brand);
    if (normalizedQuery.includes(normalizedBrand)) {
      return true;
    }
  }
  
  return false;
}

// Filter out unwanted domains
function filterResults(results: any[], excludeSephora: boolean): any[] {
  return results.filter((result) => {
    const url = result.url || "";
    const lowerUrl = url.toLowerCase();
    
    // Always filter out reddit and tiktok, generic keyword search pages 
    if (lowerUrl.includes("reddit.com") || lowerUrl.includes("tiktok.com") || lowerUrl.includes("s?k=")) {
      return false;
    }
    
    // Filter out Sephora if not in allowlist
    if (excludeSephora && lowerUrl.includes("sephora.com")) {
      return false;
    }
    
    return true;
  });
}

// Search for product with Sephora preference
export async function searchProductWithPreference(productQuery: string): Promise<any[]> {
  console.log(`[PRODUCT_SEARCH] Query: ${productQuery}`);
  
  const inSephoraAllowlist = isSephoraBrand(productQuery);
  console.log(`[PRODUCT_SEARCH] In Sephora allowlist: ${inSephoraAllowlist}`);
  
  // Modify query based on allowlist
  let searchQuery = productQuery;
  if (inSephoraAllowlist) {
    // Priority: Sephora > Amazon > brand
    searchQuery = `Find the Sephora.com product page for ${productQuery}. If you cannot find it on Sephora.com, then find the Amazon.com product page. If neither exists, find the official product page from the brand's website.`;
  } else {
    // Priority: Amazon > brand (skip Sephora)
    searchQuery = `Find the Amazon.com product page for ${productQuery}. If you cannot find it on Amazon.com, find the official product page from the brand's website. Do NOT return Sephora.com links.`;
  }
  
  console.log(`[PRODUCT_SEARCH] Search query: ${searchQuery}`);
  
  // Execute search
  const results = await fcSearch(searchQuery);
  console.log(`[PRODUCT_SEARCH] Raw results: ${results.length}`);
  
  // Filter results
  const filteredResults = filterResults(results, !inSephoraAllowlist);
  console.log(`[PRODUCT_SEARCH] Filtered results: ${filteredResults.length} (removed reddit/tiktok${!inSephoraAllowlist ? '/sephora' : ''})`);
  
  return filteredResults;
}

