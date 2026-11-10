import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const allowedRoles = new Set(["Admin", "QA Lead", "QA", "Warehouse"]);

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return jsonResponse(401, { error: "An authenticated session is required." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse(500, { error: "Provisioning service is not configured." });
  }

  const requester = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await requester.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "The session is invalid or expired." });
  }

  const { data: profile, error: profileError } = await requester
    .from("profiles")
    .select("role, status")
    .eq("id", userData.user.id)
    .single();
  if (profileError || profile?.role !== "Admin" || profile.status !== "approved") {
    return jsonResponse(403, { error: "Only approved Admin accounts can provision employees." });
  }

  let input: {
    full_name?: unknown;
    employee_id?: unknown;
    email?: unknown;
    role?: unknown;
  };
  try {
    input = await request.json();
  } catch {
    return jsonResponse(400, { error: "Request body must be valid JSON." });
  }

  const fullName = typeof input.full_name === "string" ? input.full_name.trim() : "";
  const employeeId = typeof input.employee_id === "string" ? input.employee_id.trim() : "";
  const email = typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
  const role = typeof input.role === "string" ? input.role : "";
  if (!fullName || !employeeId || !email || !allowedRoles.has(role)) {
    return jsonResponse(400, {
      error: "Full name, employee ID, email, and a supported role are required.",
    });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse(400, { error: "Enter a valid employee email address." });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: invitation, error: invitationError } =
    await admin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName, employee_id: employeeId },
    });
  if (invitationError || !invitation.user) {
    return jsonResponse(400, {
      error: invitationError?.message ?? "Could not create an invitation.",
    });
  }

  const profileRecord = {
    id: invitation.user.id,
    full_name: fullName,
    employee_id: employeeId,
    role,
    status: "approved",
  };
  const { error: insertError } = await admin.from("profiles").upsert(profileRecord);
  if (insertError) {
    const { error: cleanupError } = await admin.auth.admin.deleteUser(
      invitation.user.id,
    );
    const detail = cleanupError
      ? `${insertError.message}; cleanup also failed: ${cleanupError.message}`
      : insertError.message;
    return jsonResponse(500, {
      error: `Profile creation failed after invitation; user rollback was attempted: ${detail}`,
    });
  }

  const { error: auditError } = await admin.from("audit_logs").insert({
    action_id: `provision-${crypto.randomUUID()}`,
    action_type: "employee_provisioned",
    user_id: userData.user.id,
    module: "profiles",
    record_id: invitation.user.id,
    previous_state: null,
    new_state: profileRecord,
  });
  if (auditError) {
    return jsonResponse(500, {
      error: `Employee was provisioned, but the audit record could not be written: ${auditError.message}`,
      provisioned: true,
    });
  }

  return jsonResponse(201, {
    user_id: invitation.user.id,
    email,
    status: "approved",
  });
});
