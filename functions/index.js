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

// ── Question quality checks ────────────────────────────────────────────────
// Mirrors lib/services/question_quality.dart in the app — keep them in sync.
// The app re-checks everything too, so this is a first line of defence that
// stops bad lines (cut-off text, intro lines, fragments) at the source.

const DANGLING_END_WORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'but', 'nor', 'your', 'my', 'their',
  'our', 'its', 'because', 'than',
]);
const IMPERATIVE_START = /^(Name|Describe|Explain|Tell|Share|Imagine|Think|List|Pick|Choose)\b/;
const META_TEXT = /^(here are|here is|sure|certainly|of course|okay|ok)\b|as an ai|questions?:\s*$/i;

function cleanQuestion(raw) {
  let t = String(raw)
    .replace(/[\u2018\u2019\u201B]/g, "'")
    .replace(/[\u201C\u201D\u201E]/g, '"')
    .replace(/[\u2013\u2014]/g, ' - ')
    .replace(/\u2026/g, '...')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // é → e
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^(Q\d*[:.)]|\d+[.):]?)\s*/i, '') // "1." "2)" "Q3:"
    .replace(/^[-*]\s*/, '')                  // "- " "* "
    .trim();
  if (t.length > 2 && t.startsWith('"') && t.endsWith('"') && (t.match(/"/g) || []).length === 2) {
    t = t.slice(1, -1).trim();
  }
  return t.replace(/\s+([?!.,;:])/g, '$1');
}

function isValidQuestion(t) {
  if (t.length < 15 || t.length > 220) return false;
  const words = t.split(' ');
  if (words.length < 4 || words.length > 40) return false;
  if (!/^[A-Z"]/.test(t)) return false;
  if (!/[?.!]"?$/.test(t)) return false;
  if (!t.includes('?') && !IMPERATIVE_START.test(t)) return false;
  const lastWord = words[words.length - 1].replace(/[^A-Za-z]/g, '').toLowerCase();
  if (DANGLING_END_WORDS.has(lastWord)) return false;
  if ((t.match(/"/g) || []).length % 2 === 1) return false;
  if ((t.match(/\(/g) || []).length !== (t.match(/\)/g) || []).length) return false;
  if (META_TEXT.test(t) || t.endsWith(':')) return false;
  return true;
}

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
Every question must be one complete sentence on a single line, ending with a question mark.
IMPORTANT: Always phrase questions in the second person, addressing the reader directly as "you" or "your". Never use "I", "my", or "me". Good example: "Do you believe love can last a lifetime?" Bad example: "Do I believe love can last a lifetime?"
Do NOT ask about past specific events (e.g. "what was your first...").
Return only the questions, one per line, with no numbering or extra text.`
      : `Generate ${safeCount} thought-provoking personal reflection questions for "${cat}".
Make them open-ended, deep, and under 12 words each.
Every question must be one complete sentence on a single line, ending with a question mark.
IMPORTANT: Always phrase questions in the second person, addressing the reader directly as "you" or "your". Never use "I", "my", or "me". Good example: "Do you believe in soulmates?" Bad example: "Do I believe in soulmates?"
Return only the questions, one per line, with no numbering, intro, or extra text.`;

    let response;
    try {
      response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          // gpt-3.5-turbo was shut down by OpenAI on Oct 23, 2026.
          // gpt-6-luna is OpenAI's cheapest current model for short, high-volume
          // tasks like this. It's a reasoning model, so: reasoning_effort 'none'
          // keeps it fast/cheap, and max_completion_tokens replaces max_tokens.
          // Check https://platform.openai.com/docs/deprecations before changing.
          model: 'gpt-6-luna',
          messages: [{ role: 'user', content: prompt }],
          reasoning_effort: 'none',
          max_completion_tokens: 1200, // room for 20 questions; 500 cut lists off
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
    const choice = json.choices?.[0];
    const content = choice?.message?.content ?? '';

    let lines = content.split('\n').map(cleanQuestion).filter(l => l.length > 0);

    // If the model hit the token limit, the last line was cut off mid-sentence.
    if (choice?.finish_reason === 'length' && lines.length > 0) {
      lines = lines.slice(0, -1);
    }

    const valid = lines.filter(isValidQuestion);
    const rejected = lines.filter(l => !isValidQuestion(l));
    if (rejected.length > 0) {
      console.warn(`[generateQuestions] Dropped ${rejected.length} invalid line(s) for "${cat}":`, rejected);
    }

    // De-duplicate (case-insensitive) and never return more than requested.
    const seen = new Set();
    const questions = valid.filter(q => {
      const key = q.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, safeCount);

    if (questions.length === 0) {
      throw new functions.https.HttpsError('internal', 'OpenAI returned no questions.');
    }

    return { questions };
  });
