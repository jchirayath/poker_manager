// Handle RSVP via magic link token
// Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the function environment.

import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const url = new URL(req.url);
  const token = url.searchParams.get("token");
  const status = url.searchParams.get("status");

  if (!token || !status) {
    return new Response(
      htmlPage("Error", "Invalid RSVP link. Missing token or status parameter."),
      { status: 400, headers: { "Content-Type": "text/html", ...corsHeaders } }
    );
  }

  if (!["going", "maybe", "not_going"].includes(status)) {
    return new Response(
      htmlPage("Error", "Invalid RSVP status. Must be 'going', 'maybe', or 'not_going'."),
      { status: 400, headers: { "Content-Type": "text/html", ...corsHeaders } }
    );
  }

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
    console.log(`Processing RSVP with token ${token.substring(0, 8)}... and status ${status}`);

    // Step 1: Validate token and fetch associated game/user
    const tokenRes = await client
      .from("rsvp_tokens")
      .select(`
        id,
        game_id,
        user_id,
        expires_at,
        used_at,
        games (
          id,
          name,
          game_date,
          location,
          group_id
        ),
        profiles (
          id,
          email,
          first_name,
          last_name
        )
      `)
      .eq("token", token)
      .single();

    if (tokenRes.error || !tokenRes.data) {
      console.error(`Invalid token: ${tokenRes.error?.message}`);
      return new Response(
        htmlPage("Error", "Invalid or expired RSVP link. Please contact the game organizer."),
        { status: 404, headers: { "Content-Type": "text/html", ...corsHeaders } }
      );
    }

    const tokenData = tokenRes.data;
    const game = tokenData.games as any;
    const profile = tokenData.profiles as any;

    // Check if token is expired
    const expiresAt = new Date(tokenData.expires_at);
    if (expiresAt < new Date()) {
      console.error("Token expired");
      return new Response(
        htmlPage("Error", "This RSVP link has expired. Please contact the game organizer for a new invitation."),
        { status: 410, headers: { "Content-Type": "text/html", ...corsHeaders } }
      );
    }

    // Step 2: Upsert game_participant with RSVP status
    const participantRes = await client
      .from("game_participants")
      .upsert({
        game_id: tokenData.game_id,
        user_id: tokenData.user_id,
        rsvp_status: status,
      }, {
        onConflict: "game_id,user_id",
      })
      .select();

    if (participantRes.error) {
      console.error(`Failed to update RSVP: ${participantRes.error.message}`);
      return new Response(
        htmlPage("Error", `Failed to save RSVP: ${participantRes.error.message}`),
        { status: 500, headers: { "Content-Type": "text/html", ...corsHeaders } }
      );
    }

    // Step 3: Mark token as used
    await client
      .from("rsvp_tokens")
      .update({ used_at: new Date().toISOString() })
      .eq("id", tokenData.id);

    // Step 4: Return success page
    const statusEmoji = status === "going" ? "👍" : status === "maybe" ? "👌" : "👎";
    const statusText = status === "going" ? "You're Going!" : status === "maybe" ? "Maybe" : "Can't Make It";
    const gameDate = new Date(game.game_date);
    const formattedDate = gameDate.toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });
    const formattedTime = gameDate.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });

    return new Response(
      htmlPage(
        `${statusEmoji} RSVP Confirmed`,
        `
          <h2 style="color: #2563eb;">${statusEmoji} ${statusText}</h2>
          <p>Hi ${profile.first_name || "there"}!</p>
          <p>Your RSVP has been recorded for:</p>
          <div style="background: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0;">${game.name}</h3>
            <p><strong>Date:</strong> ${formattedDate}</p>
            <p><strong>Time:</strong> ${formattedTime}</p>
            ${game.location ? `<p><strong>Location:</strong> ${game.location}</p>` : ""}
          </div>
          <p>You can change your RSVP anytime by clicking a different option in the original email.</p>
        `
      ),
      { status: 200, headers: { "Content-Type": "text/html", ...corsHeaders } }
    );
  } catch (err: any) {
    console.error("Error processing RSVP:", err);
    return new Response(
      htmlPage("Error", `An unexpected error occurred: ${err?.message ?? "Unknown error"}`),
      { status: 500, headers: { "Content-Type": "text/html", ...corsHeaders } }
    );
  }
});

function htmlPage(title: string, content: string): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${title}</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 40px auto;
          padding: 20px;
          background: #f9fafb;
        }
        .container {
          background: white;
          padding: 40px;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
          color: #2563eb;
          margin-top: 0;
        }
        h2 {
          margin-top: 0;
        }
        p {
          margin: 15px 0;
        }
        .footer {
          text-align: center;
          color: #6b7280;
          font-size: 14px;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🃏 Poker Manager</h1>
        ${content}
        <div class="footer">
          <p>Powered by Poker Manager</p>
        </div>
      </div>
    </body>
    </html>
  `;
}
