const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

const openAiKey = defineSecret('OPENAI_API_KEY');

/**
 * Proxies question generation requests to OpenAI.
 * The API key never leaves the server — it lives in Google Cloud Secret Manager.
 *
 * Called from the Flutter app via FirebaseFunctions.instance.httpsCallable('generateQuestions')
 * Request:  { category: string, count?: number }
 * Response: { questions: string[] }
 */
exports.generateQuestions = onCall(
  { secrets: [openAiKey] },
  async (request) => {
    // Require a signed-in user — prevents abuse from outside the app
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'You must be signed in to generate questions.');
    }

    const { category, count = 5 } = request.data;

    if (!category || typeof category !== 'string' || category.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'category must be a non-empty string.');
    }

    const safeCount = Math.min(Math.max(parseInt(count) || 5, 1), 20);

    const prompt = `Generate ${safeCount} thought-provoking conversation questions for "${category.trim()}".
Make them open-ended, deep, and under 12 words each.
Return only the questions, one per line.`;

    let response;
    try {
      response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openAiKey.value()}`,
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
      throw new HttpsError('unavailable', 'Could not reach OpenAI. Please try again.');
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      console.error(`[generateQuestions] OpenAI returned ${response.status}: ${body}`);
      throw new HttpsError('internal', `OpenAI error: ${response.status}`);
    }

    const json = await response.json();
    const content = json.choices?.[0]?.message?.content ?? '';

    const questions = content
      .split('\n')
      .map(line => line.trim().replace(/^\d+\.?\s*/, '').trim())
      .filter(line => line.length > 0);

    if (questions.length === 0) {
      throw new HttpsError('internal', 'OpenAI returned no questions.');
    }

    return { questions };
  }
);
