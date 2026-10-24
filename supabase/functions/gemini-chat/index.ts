import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const systemInstruction = `Anda adalah AI Customer Service resmi dari "Doctor Computer", toko komputer dan perakitan PC terpercaya.
Bantu pelanggan dengan ramah, informatif, dan profesional berbahasa Indonesia.
Layanan kami meliputi penjualan komponen PC, perakitan, garansi, troubleshooting komputer, dan membership.
Jawab pertanyaan pengguna dengan padat, jelas, dan solusi teknis yang tepat.`;

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return respond(405, { error: "Method not allowed" });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return respond(401, { error: "Authentication required" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  if (!supabaseUrl || !anonKey || !geminiApiKey) {
    console.error("Gemini Edge Function is missing required secrets.");
    return respond(503, { error: "AI service is not configured" });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return respond(401, { error: "Invalid session" });
  }

  let payload: { query?: unknown; history?: unknown };
  try {
    payload = await request.json();
  } catch {
    return respond(400, { error: "Invalid JSON body" });
  }
  const query = typeof payload.query === "string" ? payload.query.trim() : "";
  if (!query || query.length > 2000) {
    return respond(400, { error: "query must contain 1 to 2000 characters" });
  }
  const suppliedHistory = Array.isArray(payload.history) ? payload.history : [];
  const history = suppliedHistory.slice(-12).flatMap((entry) => {
    if (!entry || typeof entry !== "object") return [];
    const role = entry.role === "user" ? "user" : entry.role === "model" ? "model" : null;
    const text = typeof entry.text === "string" ? entry.text.slice(0, 2000) : "";
    return role && text ? [{ role, parts: [{ text }] }] : [];
  });

  try {
    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": geminiApiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemInstruction }] },
          contents: [...history, { role: "user", parts: [{ text: query }] }],
          generationConfig: { maxOutputTokens: 700 },
        }),
      },
    );
    if (!response.ok) {
      console.error(`Gemini API returned HTTP ${response.status}.`);
      return respond(502, { error: "AI provider request failed" });
    }
    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("")
      .trim();
    if (!text) {
      return respond(502, { error: "AI provider returned no response" });
    }
    return respond(200, { text });
  } catch (error) {
    console.error("Gemini provider request failed:", error);
    return respond(502, { error: "AI provider request failed" });
  }
});
