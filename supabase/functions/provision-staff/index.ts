import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Staff provisioning function is missing required secrets.");
    return respond(503, { error: "Staff provisioning is not configured" });
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user: caller }, error: authError } = await callerClient.auth.getUser();
  if (authError || !caller) return respond(401, { error: "Invalid session" });

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: profile, error: profileError } = await adminClient
    .from("users")
    .select("role")
    .eq("id", caller.id)
    .maybeSingle();
  if (profileError || profile?.role !== "admin") {
    return respond(403, { error: "Only admins can provision staff" });
  }

  let payload: { email?: unknown; password?: unknown; full_name?: unknown; role?: unknown };
  try {
    payload = await request.json();
  } catch {
    return respond(400, { error: "Invalid JSON body" });
  }
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  const fullName = typeof payload.full_name === "string" ? payload.full_name.trim() : "";
  const role = payload.role === "cashier" || payload.role === "admin" ? payload.role : null;
  if (!email || !email.includes("@") || password.length < 12 || !fullName || !role) {
    return respond(400, {
      error: "Provide a valid email, a password of at least 12 characters, a name, and a staff role",
    });
  }

  const { data, error } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (error || !data.user) {
    console.error("Staff account creation failed:", error);
    return respond(400, { error: error?.message ?? "Could not create staff account" });
  }

  const { error: roleError } = await adminClient
    .from("users")
    .update({ role })
    .eq("id", data.user.id);
  if (roleError) {
    const { error: rollbackError } = await adminClient.auth.admin.deleteUser(data.user.id);
    if (rollbackError) console.error("Could not roll back failed staff provisioning:", rollbackError);
    console.error("Staff role assignment failed:", roleError);
    return respond(500, { error: "Could not assign staff role" });
  }

  return respond(200, { id: data.user.id, email, role });
});
