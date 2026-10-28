import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@10.3.0";

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return respond(405, { error: "Method not allowed" });
  }

  const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (
    !expectedSecret ||
    request.headers.get("x-webhook-secret") !== expectedSecret
  ) {
    return respond(401, { error: "Invalid webhook authentication" });
  }

  let event: {
    type?: unknown;
    record?: Record<string, unknown>;
  };
  try {
    event = await request.json();
  } catch {
    return respond(400, { error: "Invalid webhook payload" });
  }

  const record = event.record;
  const metadata =
    record?.metadata && typeof record.metadata === "object"
      ? record.metadata as Record<string, unknown>
      : {};
  if (
    event.type !== "INSERT" ||
    metadata.event_source !== "order_status"
  ) {
    return respond(200, { skipped: true });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");
  if (
    !supabaseUrl ||
    !serviceRoleKey ||
    !projectId ||
    !clientEmail ||
    !privateKey
  ) {
    console.error("Order push function is missing required secrets.");
    return respond(503, { error: "Push notifications are not configured" });
  }

  const userId = record?.user_id?.toString();
  const title = record?.title?.toString();
  const body = record?.message?.toString();
  if (!userId || !title || !body) {
    return respond(400, { error: "Notification record is incomplete" });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: devices, error: deviceError } = await adminClient
    .from("user_push_tokens")
    .select("token")
    .eq("user_id", userId);
  if (deviceError) {
    console.error("Could not load registered push devices:", deviceError);
    return respond(500, { error: "Could not load push devices" });
  }
  if (!devices?.length) return respond(200, { sent: 0 });

  try {
    const auth = new JWT({
      email: clientEmail,
      key: privateKey.replace(/\\n/g, "\n"),
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const { token: accessToken } = await auth.getAccessToken();
    if (!accessToken) throw new Error("Could not obtain an FCM access token");

    const orderId = record?.order_id?.toString() ?? "";
    const results = await Promise.all(
      devices.map(async ({ token }) => {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body },
                data: {
                  route: "/order-history",
                  order_id: orderId,
                },
                android: { priority: "HIGH" },
                apns: {
                  headers: { "apns-priority": "10" },
                  payload: { aps: { sound: "default" } },
                },
              },
            }),
          },
        );

        if (response.ok) return true;
        const errorDetails = await response.text();
        console.error(
          `FCM delivery failed (${response.status}): ${errorDetails.slice(0, 2000)}`,
        );
        return false;
      }),
    );
    const sent = results.filter(Boolean).length;
    if (sent !== results.length) {
      return respond(502, { sent, failed: results.length - sent });
    }
    return respond(200, { sent });
  } catch (error) {
    console.error("Order push delivery failed:", error);
    return respond(500, { error: "Push delivery failed" });
  }
});
