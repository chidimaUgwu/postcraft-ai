// functions/index.js
// PostCraft AI – Firebase Cloud Functions
// Handles all AI caption generation and Firestore writes

const functions  = require('firebase-functions');
const admin      = require('firebase-admin');
const { OpenAI } = require('openai');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Build the AI prompt based on property data + platform
// ─────────────────────────────────────────────────────────────────────────────
function buildPrompt(data, platform) {
  const {
    title, price, pricePeriod, address,
    propertyType, compoundType, numTenants,
    bedrooms, bathrooms, toilets,
    waterAvailable, electricityAvailable, parkingAvailable,
    extraFeatures = [],
  } = data;

  const featureLines = [
    waterAvailable       ? '• Water supply available'    : '• No water supply',
    electricityAvailable ? '• Electricity available'     : '• No electricity',
    parkingAvailable     ? '• Parking space available'   : '',
    ...extraFeatures.map(f => `• ${f}`),
  ].filter(Boolean).join('\n');

  const priceStr = `₦${Number(price).toLocaleString()} ${pricePeriod || 'monthly'}`;

  const platformRules = {
    whatsapp:  'WhatsApp → short paragraphs, direct language, *bold* key points with asterisks, end with clear CTA',
    instagram: 'Instagram → punchy hook, lifestyle appeal, 5–8 relevant Nigerian real estate hashtags, emojis throughout',
    facebook:  'Facebook → detailed and warm, community feel, 3–4 paragraphs, clear benefits, strong CTA',
    twitter:   'Twitter/X → max 280 characters, catchy hook, 2 hashtags only, extremely concise',
    linkedin:  'LinkedIn → professional investor-focused tone, ROI angle, sophisticated language',
  };

  return `You are a professional Nigerian real estate marketing expert.

Generate a HIGH-CONVERTING property caption for ${platform.toUpperCase()}.

PROPERTY DETAILS:
Title: ${title}
Price: ${priceStr}
Location: ${address || 'Lagos, Nigeria'}
Type: ${propertyType.replace(/_/g, ' ')}
Compound: ${compoundType.replace(/_/g, ' ')}${compoundType === 'shared_compound' && numTenants ? ` (${numTenants} tenants)` : ''}
Bedrooms: ${bedrooms} | Bathrooms: ${bathrooms} | Toilets: ${toilets}

FEATURES:
${featureLines || 'Standard features'}

PLATFORM INSTRUCTIONS:
${platformRules[platform] || 'Write a professional property listing caption.'}

REQUIRED STRUCTURE:
1. Start with a strong hook: "🏠 FOR RENT:" or "🏡 FOR SALE:" depending on price period
2. Highlight the most important details clearly
3. Add lifestyle appeal ("Wake up to..." / "Perfect for...")
4. Add urgency ("Limited availability" / "Viewing strictly by appointment")
5. End with CTA: "📲 Call/WhatsApp now: +234 XXX XXX XXXX"

Return ONLY the caption text. No explanation. No extra formatting outside the caption itself.`;
}

// ─────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: generateCaption
// Called from Flutter app via Firebase Cloud Functions SDK
// ─────────────────────────────────────────────────────────────────────────────
exports.generateCaption = functions
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onCall(async (data, context) => {

    // 1. Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be logged in to generate captions.'
      );
    }

    const { postId, platform, propertyData } = data;

    // 2. Validate inputs
    if (!postId || !platform || !propertyData) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'postId, platform, and propertyData are required.'
      );
    }

    const validPlatforms = ['whatsapp', 'instagram', 'facebook', 'twitter', 'linkedin'];
    if (!validPlatforms.includes(platform)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Platform must be one of: ${validPlatforms.join(', ')}`
      );
    }

    // 3. Get user's API key from Firestore settings (or fall back to env)
    let openaiKey = functions.config().openai?.key || process.env.OPENAI_API_KEY;
    try {
      const settingsDoc = await db
        .collection('settings')
        .doc(context.auth.uid)
        .get();
      if (settingsDoc.exists && settingsDoc.data().openaiApiKey) {
        openaiKey = settingsDoc.data().openaiApiKey;
      }
    } catch (_) {}

    if (!openaiKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'No OpenAI API key configured. Add one in Settings.'
      );
    }

    // 4. Build prompt and call OpenAI
    const prompt = buildPrompt(propertyData, platform);
    const openai = new OpenAI({ apiKey: openaiKey });

    let captionText;
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 700,
        temperature: 0.82,
      });
      captionText = completion.choices[0].message.content.trim();
    } catch (err) {
      console.error('OpenAI error:', err.message);
      throw new functions.https.HttpsError(
        'internal',
        'AI generation failed: ' + err.message
      );
    }

    // 5. Get next generation number for this post + platform
    const versionsRef = db
      .collection('caption_versions')
      .where('postId',   '==', postId)
      .where('platform', '==', platform)
      .orderBy('generationNum', 'desc')
      .limit(1);

    const lastSnap = await versionsRef.get();
    const nextGen  = lastSnap.empty ? 1 : (lastSnap.docs[0].data().generationNum || 0) + 1;

    // 6. Mark previous versions as not selected
    const allVersions = await db
      .collection('caption_versions')
      .where('postId',     '==', postId)
      .where('platform',   '==', platform)
      .where('isSelected', '==', true)
      .get();

    const batch = db.batch();
    allVersions.docs.forEach(doc => batch.update(doc.ref, { isSelected: false }));

    // 7. Save new version (never deletes old ones)
    const newVersionRef = db.collection('caption_versions').doc();
    batch.set(newVersionRef, {
      id:            newVersionRef.id,
      postId,
      userId:        context.auth.uid,
      platform,
      captionText,
      isSelected:    true,
      generationNum: nextGen,
      createdAt:     admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 8. Return result to Flutter app
    return {
      success:       true,
      captionId:     newVersionRef.id,
      captionText,
      generationNum: nextGen,
      platform,
    };
  });

// ─────────────────────────────────────────────────────────────────────────────
// CLOUD FUNCTION: deletePost
// Cleans up all sub-collections when a post is deleted
// ─────────────────────────────────────────────────────────────────────────────
exports.deletePost = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required.');
  }

  const { postId } = data;
  if (!postId) {
    throw new functions.https.HttpsError('invalid-argument', 'postId required.');
  }

  // Verify ownership
  const postDoc = await db.collection('posts').doc(postId).get();
  if (!postDoc.exists || postDoc.data().userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Not your post.');
  }

  const batch = db.batch();

  // Delete caption versions
  const versions = await db.collection('caption_versions').where('postId', '==', postId).get();
  versions.docs.forEach(d => batch.delete(d.ref));

  // Delete images records
  const images = await db.collection('images').where('postId', '==', postId).get();
  images.docs.forEach(d => batch.delete(d.ref));

  // Delete the post itself
  batch.delete(db.collection('posts').doc(postId));

  await batch.commit();
  return { success: true };
});
