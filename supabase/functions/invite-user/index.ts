// Invite a user to a group and send Supabase-managed invite email
// Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the function environment.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function randomPassword(): string {
  // 16 chars from UUID without dashes
  return crypto.randomUUID().replace(/-/g, "").slice(0, 16);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Check service role key
  if (!serviceRoleKey) {
    console.error("SUPABASE_SERVICE_ROLE_KEY not set in environment");
    return jsonResponse({ error: "Server configuration error: missing service role key" }, 500);
  }

  // Log auth header for debugging
  const authHeader = req.headers.get("authorization");
  console.log("Auth header present:", !!authHeader);
  if (authHeader) {
    console.log("Auth header length:", authHeader.length);
  }

  let payload: {
    groupId?: string;
    email?: string;
    fullName?: string;
    role?: string;
    groupName?: string;
  };

  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const groupId = payload.groupId?.trim();
  const email = payload.email?.trim().toLowerCase();
  const fullName = payload.fullName?.trim() ?? "";
  const role = payload.role?.trim() ?? "member";
  const groupName = payload.groupName?.trim() ?? "";

  if (!groupId || !email) {
    return jsonResponse({ error: "groupId and email are required" }, 400);
  }

  const [firstName, ...rest] = fullName.split(" ").filter(Boolean);
  const lastName = rest.join(" ");
  const tempPassword = randomPassword();

  const client = createClient(supabaseUrl, serviceRoleKey, {
    global: {
      headers: { Authorization: `Bearer ${serviceRoleKey}` },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    console.log(`Inviting ${email} to group ${groupId}`);

    // Step 1: send Supabase-managed invite email (creates user if not exists)
    const invite = await client.auth.admin.inviteUserByEmail(email, {
      data: {
        full_name: fullName,
        group_id: groupId,
        group_name: groupName,
        temp_password: tempPassword,
        must_reset_password: true,
      },
    });

    let userId = invite.data?.user?.id;

    // If user already exists, fall back to finding by email in profiles
    if (invite.error && invite.error.message?.toLowerCase().includes("registered")) {
      console.log(`User ${email} already exists, looking up in profiles`);
      const existing = await client
        .from("profiles")
        .select("id")
        .eq("email", email)
        .maybeSingle();
      if (existing.data?.id) {
        userId = existing.data.id as string;
      } else {
        return jsonResponse({ error: "User already exists and profile not found" }, 409);
      }
    } else if (invite.error) {
      console.error(`Invite error: ${invite.error.message}`);
      return jsonResponse({ error: invite.error.message }, 400);
    }

    if (!userId) {
      return jsonResponse({ error: "Failed to determine user id" }, 400);
    }

    // Step 2: set a temp password and metadata (forces password change next login)
    const updateRes = await client.auth.admin.updateUserById(userId, {
      password: tempPassword,
      user_metadata: {
        full_name: fullName,
        group_id: groupId,
        group_name: groupName,
        temp_password: tempPassword,
        must_reset_password: true,
      },
    });

    if (updateRes.error) {
      return jsonResponse({ error: updateRes.error.message }, 400);
    }

    // Step 3: upsert profile
    const profileRes = await client.from("profiles").upsert({
      id: userId,
      email,
      first_name: firstName ?? "",
      last_name: lastName,
      country: "United States",
      updated_at: new Date().toISOString(),
    });

    if (profileRes.error) {
      return jsonResponse({ error: profileRes.error.message }, 400);
    }

    // Step 4: add to group_members
    const gmRes = await client.from("group_members").upsert({
      group_id: groupId,
      user_id: userId,
      role,
    });

    if (gmRes.error) {
      return jsonResponse({ error: gmRes.error.message }, 400);
    }

    return jsonResponse({ status: "ok", userId, tempPassword });
  } catch (err) {
    return jsonResponse({ error: err?.message ?? "Unknown error" }, 500);
  }
});
