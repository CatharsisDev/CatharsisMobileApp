// Use Firebase Functions v1 (Gen 1) for the callable function.
// Gen 2 runs on Cloud Run, which requires GCP IAM auth at the infrastructure
// level — GCP org policies often block allUsers as invoker, causing every
// Flutter client call to fail with UNAUTHENTICATED before the handler runs.
// Gen 1 callable functions handle Firebase Auth tokens natively, no IAM config needed.
//
// Note: import from 'firebase-functions/v1' — in firebase-functions v6 the root
// module no longer exposes runWith(), but the v1 submodule still does.
const functions = require('firebase-functions/v1');

// The OpenAI API key is stored in Google Cloud Secret Manager.
// Declaring it in runWith() makes it available as process.env.OPENAI_API_KEY
// inside the function without ever exposing it to clients.
const OPENAI_API_KEY_SECRET = 'OPENAI_API_KEY';

/**
 * Proxies question generation requests to OpenAI.
 * The API key never leaves the server — it lives in Google Cloud Secret Manager.
 *
 * Called from the Flutter app via FirebaseFunctions.instance.httpsCallable('generateQuestions')
 * Request:  { category: string, count?: number, mode?: 'solo' | 'duo' }
 * Response: { questions: string[] }
 */
exports.generateQuestions = functions
  .runWith({ secrets: [OPENAI_API_KEY_SECRET] })
  .https.onCall(async (data, context) => {
    // Require a signed-in user — prevents abuse from outside the app.
    // In Gen 1 callable functions, auth context is in `context.auth`.
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be signed in to generate questions.'
      );
    }

    const { category, count = 5, mode = 'solo' } = data;

    if (!category || typeof category !== 'string' || category.trim().length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'category must be a non-empty string.'
      );
    }

    const safeCount = Math.min(Math.max(parseInt(count) || 5, 1), 20);
    const cat = category.trim();
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      console.error('[generateQuestions] OPENAI_API_KEY secret not available');
      throw new functions.https.HttpsError('internal', 'Server configuration error.');
    }

    // Duo mode: questions must reveal values/preferences two people can compare.
    // Solo mode: open-ended personal reflection questions.
    const prompt = mode === 'duo'
      ? `Generate ${safeCount} compatibility questions for the category "${cat}" to be used in a couples or friends matching game.
Each question must reveal a personal value, preference, or belief that two people can meaningfully compare.
The question should be answerable by anyone (not require specific life experience).
Keep each question under 15 words, open-ended, and thought-provoking.
IMPORTANT: Always phrase questions in the second person, addressing the reader directly as "you" or "your". Never use "I", "my", or "me". Good example: "Do you believe love can last a lifetime?" Bad example: "Do I believe love can last a lifetime?"
Do NOT ask about past specific events (e.g. "what was your first...").
Return only the questions, one per line, with no numbering or extra text.`
      : `Generate ${safeCount} thought-provoking personal reflection questions for "${cat}".
Make them open-ended, deep, and under 12 words each.
IMPORTANT: Always phrase questions in the second person, addressing the reader directly as "you" or "your". Never use "I", "my", or "me". Good example: "Do you believe in soulmates?" Bad example: "Do I believe in soulmates?"
Return only the questions, one per line.`;

    let response;
    try {
      response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: 'gpt-3.5-turbo',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 500,
          temperature: 0.8,
        }),
      });
    } catch (networkError) {
      console.error('[generateQuestions] Network error calling OpenAI:', networkError);
      throw new functions.https.HttpsError('unavailable', 'Could not reach OpenAI. Please try again.');
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      console.error(`[generateQuestions] OpenAI returned ${response.status}: ${body}`);
      throw new functions.https.HttpsError('internal', `OpenAI error: ${response.status}`);
    }

    const json = await response.json();
    const content = json.choices?.[0]?.message?.content ?? '';

    const questions = content
      .split('\n')
      .map(line => line
        .trim()
        .replace(/^\d+\.?\s*/, '')   // strip leading numbers: "1." or "1 "
        .replace(/^[-–—•*]\s*/, '')  // strip leading dashes/bullets: "- " "– " "• " "* "
        .trim()
      )
      .filter(line => line.length > 0);

    if (questions.length === 0) {
      throw new functions.https.HttpsError('internal', 'OpenAI returned no questions.');
    }

    return { questions };
  });
