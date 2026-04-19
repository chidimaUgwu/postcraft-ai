import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_theme.dart';

class GeminiService {
  /// Calls Google Gemini API directly and returns the generated caption text.
  static Future<String> generateCaption({
    required String apiKey,
    required String platform,
    required Map<String, dynamic> propertyData,
    String tone = 'professional',
    String currency = 'NGN',
    String language = 'en',
    String country = 'Nigeria',
    Map<String, dynamic> contactInfo = const {},
  }) async {
    final prompt = _buildPrompt(
        propertyData, platform, tone, contactInfo, currency, language, country);
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.92,
          'maxOutputTokens': 1800,
        },
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final message = error['error']?['message'] ??
          'Gemini API error (${response.statusCode})';
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response generated from Gemini.');
    }

    final parts = candidates[0]['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty response from Gemini.');
    }

    return (parts[0]['text'] as String).trim();
  }

  static String _buildPrompt(
    Map<String, dynamic> data,
    String platform,
    String tone,
    Map<String, dynamic> contact,
    String currency,
    String language,
    String country,
  ) {
    // ── STEP 2: PROPERTY DETAILS ────────────────────────────────────────────
    final title = (data['title'] ?? '').toString();
    final price = data['price'] ?? 0;
    final pricePeriod = (data['pricePeriod'] ?? 'monthly').toString();
    final address = (data['address'] ?? '').toString();
    final propertyType =
        (data['propertyType'] ?? '').toString().replaceAll('_', ' ');
    final compoundType =
        (data['compoundType'] ?? '').toString().replaceAll('_', ' ');
    final numTenants = data['numTenants'];
    final bedrooms = data['bedrooms'] ?? 0;
    final bathrooms = data['bathrooms'] ?? 0;
    final toilets = data['toilets'] ?? 0;
    final waterAvailable = data['waterAvailable'] == true;
    final electricityAvailable = data['electricityAvailable'] == true;
    final parkingAvailable = data['parkingAvailable'] == true;
    final extraFeatures = List<String>.from(data['extraFeatures'] ?? []);

    // ── STEP 1: MEDIA COUNT ─────────────────────────────────────────────────
    final imageCount = (data['imageCount'] ?? 0) as int;

    // Furnishing comes from the user directly (property details screen).
    // Falls back to a feature-derived guess if the user didn't select one.
    const furnishingLabels = {
      'unfurnished': 'Unfurnished',
      'semi_furnished': 'Semi-furnished',
      'fully_furnished': 'Fully furnished',
    };
    String furnishing = furnishingLabels[data['furnishing']] ?? '';
    if (furnishing.isEmpty) {
      final featuresLower = extraFeatures.map((f) => f.toLowerCase()).toList();
      furnishing = 'Unfurnished';
      if (featuresLower.any((f) =>
          f.contains('smart home') ||
          f.contains('air conditioning') ||
          (f.contains('wardrobe') && f.contains('kitchen')))) {
        furnishing = 'Fully furnished';
      } else if (featuresLower.any(
          (f) => f.contains('kitchen cabinet') || f.contains('wardrobe'))) {
        furnishing = 'Semi-furnished';
      }
    }

    // Build full amenities list (utilities + extra features)
    final amenities = <String>[];
    if (waterAvailable) amenities.add('24/7 water supply / borehole');
    if (electricityAvailable) amenities.add('Stable electricity supply');
    if (parkingAvailable) amenities.add('Secure parking space');
    amenities.addAll(extraFeatures);
    final amenitiesList = amenities.isEmpty
        ? '- Standard amenities'
        : amenities.map((a) => '- $a').join('\n');

    // Pricing strings — use the user\'s selected currency
    final currencySymbol = AppCurrencies.symbolFor(currency);
    final priceStr = '$currencySymbol${_formatNumber(price)}';
    final isRent = pricePeriod == 'monthly' || pricePeriod == 'yearly';
    final priceLabel = isRent
        ? '$priceStr per ${pricePeriod == 'monthly' ? 'month' : 'year'}'
        : '$priceStr (outright purchase)';
    final rentOrSale = isRent ? 'FOR RENT' : 'FOR SALE';

    final compoundInfo = compoundType.contains('shared') && numTenants != null
        ? 'Shared compound ($numTenants tenants)'
        : compoundType.contains('self')
            ? 'Self-contained compound (private & secure)'
            : compoundType;

    // Description — user-written if provided, otherwise an auto-synth fallback.
    final userDescription = (data['description'] ?? '').toString().trim();
    final description = userDescription.isNotEmpty
        ? userDescription
        : '$bedrooms-bedroom $propertyType in ${address.isNotEmpty ? address : 'a prime location'}, $compoundInfo, $furnishing.';

    // ── AGENT / USER INFO (from Settings + Auth) ────────────────────────────
    final userName = (contact['userName'] ?? '').toString();
    final userEmail = (contact['userEmail'] ?? '').toString();
    final phone = (contact['phoneNumber'] ?? '').toString();
    final whatsapp = (contact['whatsappNumber'] ?? '').toString();
    final website = (contact['website'] ?? '').toString();
    final bizName = (contact['businessName'] ?? '').toString();
    final bizLocation = (contact['businessLocation'] ?? '').toString();

    // Build two tiers: company first (if present), then individual agent.
    // Give them visual hierarchy so the AI keeps them BOTH in the CTA.
    final companyLines = <String>[];
    if (bizName.isNotEmpty) companyLines.add('🏢 Company: $bizName');
    if (bizLocation.isNotEmpty) {
      companyLines.add('📍 Office Address: $bizLocation');
    }
    if (website.isNotEmpty) companyLines.add('🌐 Website/Social: $website');

    final agentLines = <String>[];
    if (userName.isNotEmpty) agentLines.add('👤 Agent: $userName');
    if (phone.isNotEmpty) agentLines.add('📞 Call: $phone');
    if (whatsapp.isNotEmpty) {
      agentLines.add('💬 WhatsApp: $whatsapp');
    } else if (phone.isNotEmpty) {
      agentLines.add('💬 WhatsApp: $phone');
    }
    if (userEmail.isNotEmpty) agentLines.add('✉️ Email: $userEmail');

    final hasCompany = companyLines.isNotEmpty;
    final hasContact = companyLines.isNotEmpty || agentLines.isNotEmpty;
    final agentBlock = hasContact
        ? [
            if (hasCompany) ...[
              'COMPANY (lead with this in the CTA — it is the brand buyers will trust):',
              ...companyLines,
            ],
            if (agentLines.isNotEmpty) ...[
              if (hasCompany) '',
              'AGENT (direct point of contact):',
              ...agentLines,
            ],
          ].join('\n')
        : '(No contact details saved — end with "Send a DM for viewing schedule")';

    // ── STEP 4: TONE ────────────────────────────────────────────────────────
    const toneMap = {
      'professional':
          'Professional — clean, minimal, corporate. Authoritative yet approachable. Solid-value positioning, not flashy.',
      'casual':
          'Casual — friendly, warm, conversational. Like texting a friend about an amazing find.',
      'luxury':
          'Luxury — premium, elegant, aspirational. Prestigious, opulent, high-end magazine energy. Words like "exquisite", "prestigious", "discerning clientele", "exclusive residence".',
      'urgent':
          'Urgent — scarcity, fast action, FOMO. "Only 2 units left", "Viewing this weekend only", "Serious clients only".',
    };
    final toneDescription = toneMap[tone] ?? toneMap['professional']!;

    // ── STEP 3: PLATFORM RULES ──────────────────────────────────────────────
    final platformRules = _platformRules(
      platform: platform,
      rentOrSale: rentOrSale,
      propertyType: propertyType,
      address: address,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      toilets: toilets,
      priceStr: priceStr,
      priceLabel: priceLabel,
      isRent: isRent,
      firstAmenity: amenities.isNotEmpty ? amenities.first : 'All amenities',
      compoundInfo: compoundInfo,
      waterAvailable: waterAvailable,
      electricityAvailable: electricityAvailable,
      parkingAvailable: parkingAvailable,
      tone: tone,
    );

    // ── LOCALE (language, currency, base country) ──────────────────────────
    final languageName = AppLanguages.byCode[language] ?? 'English';
    final localeBlock = '''🌍 LOCALE:
- Write the caption in: $languageName (language code: $language)
- Currency: $currency ($currencySymbol) — use it for every price reference; do NOT convert or show other currencies unless the tone is "luxury" and only then as a parenthetical
- Base country / market: $country — tailor nearby-landmarks, neighbourhood names, slang, and cultural references to this market (e.g. PHCN/NEPA in Nigeria, ECG in Ghana, KPLC in Kenya)
- Hashtags must include this country and/or city where relevant''';

    // ── FINAL PROMPT ────────────────────────────────────────────────────────
    return '''You are a professional real estate marketing expert and copywriter.

Your task is to generate a HIGH-CONVERTING social media caption for a property listing.

---

$localeBlock

---

📍 PROPERTY INFORMATION:
- Title: ${title.isEmpty ? 'Untitled property' : title}
- Listing Type: $rentOrSale
- Location: ${address.isEmpty ? 'Nigeria (prime area)' : address}
- Price: $priceLabel
- Property Type: $propertyType
- Compound: $compoundInfo
- Bedrooms: $bedrooms
- Bathrooms: $bathrooms
- Toilets: $toilets
- Furnishing: $furnishing
- Description ${userDescription.isNotEmpty ? '(WRITTEN BY THE USER — treat as seed content; weave its facts and angle into the caption)' : '(auto-generated fallback)'}: $description

---

🏢 AMENITIES & FEATURES:
$amenitiesList

---

📸 MEDIA CONTEXT:
The post includes $imageCount image${imageCount == 1 ? '' : 's'}/video${imageCount == 1 ? '' : 's'} showing the property.
Write the caption in a way that complements visuals — do NOT describe images literally; enhance their appeal.
Naturally mention that photos/videos are attached (e.g. "swipe through the photos", "watch the walkthrough").

---

🎯 TARGET PLATFORM:
Platform: $platform

$platformRules

---

🎭 TONE & STYLE:
Tone selected by user: $tone
$toneDescription

---

👤 AGENT / BRAND INFO (you MUST include this in the CTA, exactly as shown):
$agentBlock

---

🧠 WRITING RULES:
- Start with a strong HOOK (attention-grabbing first line)
- Show PRICE early (within the first 3 lines)
- Highlight LOCATION value — mention reasonable nearby landmarks (schools, markets, malls, transport) even if not provided
- Structure content with sections, spacing, and emojis when suitable for the platform
- Emphasise BENEFITS, not just features (e.g. "24/7 water — no tanker stress")
- Include urgency if the tone is "urgent" or the platform thrives on it
- Use EVERY amenity listed above — do not drop any (except WhatsApp, where length is capped)
- First-person or second-person voice — whichever suits $platform best
- Length: follow the PLATFORM-SPECIFIC rules above. If a platform caps length (WhatsApp 1024 chars, Twitter/X 280 chars), the cap wins over "longer is better".
- End with a CLEAR, STRONG CTA:
  * If a COMPANY is provided, LEAD the CTA with the company name — that is the brand the buyer will trust and remember. Then the agent direct line (call/WhatsApp/email) underneath it.
  * If only an agent is provided, use the agent details as the sole point of contact.
  * Include the office address and website/social handle when provided — they build credibility.
- Add 5–7 relevant hashtags at the end (except Twitter/X where hashtags are part of the 280-char limit, and WhatsApp where hashtags are not used)

---

🚫 AVOID:
- Generic phrases ("dream home", "must see" without substance)
- Repetition of the same fact in different words
- Overly robotic or AI-sounding tone
- Markdown formatting (**bold**, _italics_) — use CAPS and emojis instead
- Preambles like "Here is your caption" — output ONLY the caption itself

---

✅ OUTPUT:
Generate ONE high-quality caption tailored to $platform in the $tone tone.
Make it detailed, engaging, conversion-focused, and ready to copy-paste-post with ZERO edits.
Output ONLY the caption. Nothing else.''';
  }

  /// Per-platform structural rules inserted into the main prompt.
  static String _platformRules({
    required String platform,
    required String rentOrSale,
    required String propertyType,
    required String address,
    required int bedrooms,
    required int bathrooms,
    required int toilets,
    required String priceStr,
    required String priceLabel,
    required bool isRent,
    required String firstAmenity,
    required String compoundInfo,
    required bool waterAvailable,
    required bool electricityAvailable,
    required bool parkingAvailable,
    required String tone,
  }) {
    switch (platform) {
      case 'whatsapp':
        return '''WhatsApp rules — HARD LIMIT: 1024 characters total (WhatsApp caption cap). Aim for ~850 chars / 120–140 words so nothing is truncated.

STRUCTURE (follow exactly — KEEP IT TIGHT, short lines only):
🏡 $rentOrSale: $bedrooms-BED ${propertyType.toUpperCase()} — ${address.isNotEmpty ? address.toUpperCase() : 'PRIME LOCATION'}

📍 ${address.isNotEmpty ? address : 'Prime area'}
💰 $priceLabel

🏢 $bedrooms bed • $bathrooms bath • $toilets toilet • $compoundInfo

✅ FEATURES: (bullet the TOP 5–6 amenities only, one per line with ✔. If more exist, summarise the rest in one line — do not list all.)

🌟 (ONE short sentence on why this property is a smart pick)

📞 CONTACT: (lead with the COMPANY/BRAND if provided, then the agent. Each on its own line with its emoji — call, WhatsApp, email, office address.)

⏳ Book a viewing today — units move fast.

STRICT RULES for WhatsApp:
- NO hashtags
- NO long paragraphs — short lines, heavy emoji
- If the full content would exceed 1024 chars, CUT the "why this property" line, then trim amenities to top 3 — NEVER cut the price, location, or contact block
- Output ONLY the caption text, nothing else''';

      case 'instagram':
        return '''Instagram rules — engaging, visual, emotional (hook + rich body + hashtags):

STRUCTURE:
1. HOOK (first 2 lines that show before the "... more" fold):
   🔥 ${isRent ? 'FROM $priceStr/month' : priceStr} — ${propertyType.toUpperCase()} IN ${address.isNotEmpty ? address.toUpperCase() : 'PRIME LOCATION'}
   $bedrooms-bed • $bathrooms-bath • $firstAmenity

2. LIFESTYLE PARAGRAPH (3–4 sentences painting the feel of living there)

3. 🏢 WHAT IS INSIDE: (bullet each room + compound detail)

4. ✨ FEATURES & FACILITIES: (every amenity on its own line with ✔)

5. 🌆 WHY THIS LOCATION: (2–3 sentences with nearby schools/malls/transport)

6. 📞 CTA BLOCK: (all contact details)

7. 10–14 relevant hashtags on their own line at the end.

Length: 260–380 words before hashtags.''';

      case 'facebook':
        return '''Facebook rules — detailed brochure style (Marketplace / community groups):

STRUCTURE:
1. HEADLINE with emoji — \$rentOrSale + property type + area
2. OPENING STORY (3–4 sentences addressing buyer pain points)
3. 🏢 FULL BREAKDOWN (property type, compound, bedrooms, bathrooms, toilets, location, price — bulleted)
4. ✅ FEATURES & AMENITIES with benefit framing ("✔ 24/7 water — no tanker stress")
5. 🌆 NEIGHBOURHOOD paragraph (schools, markets, hospitals, transport, security)
6. 👥 PERFECT FOR: (buyer personas)
7. ⏳ URGENCY + CTA
8. 📞 CONTACT block (all details)
9. Engagement prompt: "Comment INTERESTED below" / "Tag someone house-hunting"

Length: 320–460 words. 5–7 hashtags at the end.''';

      case 'twitter':
        return '''Twitter/X rules — STRICT 280-character limit total (including hashtags).

Format:
🏡 $rentOrSale: ${bedrooms}bed/${bathrooms}bath $propertyType • ${address.isNotEmpty ? address : 'Prime area'} • $priceLabel • $firstAmenity • DM/Call now #RealEstate #${(address.isNotEmpty ? address.split(',').first.replaceAll(' ', '') : 'Property')}

Concise but impactful. Count characters — must stay under 280.''';

      case 'linkedin':
        return '''LinkedIn rules — professional, investment-focused, structured:

STRUCTURE (follow exactly):

✨🏙️ ${rentOrSale.contains('RENT') ? 'PREMIUM' : 'INVESTMENT-GRADE'} ${propertyType.toUpperCase()} IN ${address.isNotEmpty ? address.toUpperCase() : 'PRIME LOCATION'} — ${tone == 'luxury' ? 'LIVE THE ELITE LIFE' : 'SMART LIVING, PRIME LOCATION'} 🏙️✨

📍 Location: ${address.isNotEmpty ? address : 'Prime area'}
💰 Price: $priceLabel

(1 paragraph positioning the property and its target buyer — 2–3 sentences)

🏢 AVAILABLE UNIT:
🔹 $propertyType • Compound: $compoundInfo
🔹 $bedrooms bedroom${bedrooms == 1 ? '' : 's'} • $bathrooms bathroom${bathrooms == 1 ? '' : 's'} • $toilets toilet${toilets == 1 ? '' : 's'}

🌟 FEATURES: (every amenity bulleted with ✨)

🏊 FACILITIES & UTILITIES:
✔ ${waterAvailable ? '24/7 water supply (no tanker stress)' : 'Water supply on schedule'}
✔ ${electricityAvailable ? 'Stable electricity + standby options' : 'Standard electricity'}
✔ ${parkingAvailable ? 'Secure parking' : 'Street parking nearby'}

🌆 WHY THIS LOCATION: (3–4 bullets on neighbourhood value + investment angle)

📊 WHY THIS IS A SMART ${isRent ? 'RENTAL' : 'INVESTMENT'}: (2–3 bullets on ROI / market positioning)

📞 BOOK A PRIVATE VIEWING: (all agent/brand contact details on their own lines)

🔐 ${tone == 'luxury' ? 'Luxury units at this price point are limited — secure yours now.' : 'Units at this price point move fast — book early.'}

5–7 professional hashtags at the end. Length: 320–480 words.''';

      case 'tiktok':
        return '''TikTok rules — short, catchy, hook-driven (attention span = 3 seconds):

Output TWO blocks separated by the line ===

BLOCK 1 — CAPTION (under the video): max 2 lines. Price shock + location + CTA. Then 6–8 hashtags on their own line.

===

BLOCK 2 — ON-SCREEN TEXT (overlays): 4–6 lines, 2–5 words each. One line per cut.

Total output under 120 words.''';

      default:
        return 'Default rules — detailed, professional caption of 250+ words. End with contact CTA + 5–7 hashtags.';
    }
  }

  static String _formatNumber(dynamic number) {
    final n = int.tryParse(number.toString().split('.').first) ?? 0;
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}
