// Send RSVP emails for a scheduled game
// Requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and RESEND_API_KEY in the function environment.
// Uses Resend for transactional emails (free tier: 3,000 emails/month, 100/day)

import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const resendApiKey = Deno.env.get("RESEND_API_KEY");

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

// Generate a secure random token for RSVP magic links
function generateToken(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

interface RSVPEmailPayload {
  gameId: string;
  userId?: string; // If provided, send to one user only; otherwise send to all group members
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!serviceRoleKey) {
    console.error("SUPABASE_SERVICE_ROLE_KEY not set in environment");
    return jsonResponse({ error: "Server configuration error: missing service role key" }, 500);
  }

  if (!resendApiKey) {
    console.error("RESEND_API_KEY not set in environment");
    return jsonResponse({ error: "Server configuration error: missing Resend API key" }, 500);
  }

  let payload: RSVPEmailPayload;

  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const gameId = payload.gameId?.trim();

  if (!gameId) {
    return jsonResponse({ error: "gameId is required" }, 400);
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
    console.log(`Sending RSVP emails for game ${gameId}`);

    // Step 1: Fetch game details
    const gameRes = await client
      .from("games")
      .select(`
        id,
        name,
        game_date,
        location,
        buyin_amount,
        max_players,
        group_id,
        groups (
          id,
          name
        )
      `)
      .eq("id", gameId)
      .single();

    if (gameRes.error || !gameRes.data) {
      console.error(`Game not found: ${gameRes.error?.message}`);
      return jsonResponse({ error: "Game not found" }, 404);
    }

    const game = gameRes.data;
    const groupName = (game.groups as any)?.name || "Poker Group";

    // Step 2: Fetch group members (recipients)
    let recipientsQuery = client
      .from("group_members")
      .select(`
        user_id,
        profiles (
          id,
          email,
          first_name,
          last_name
        )
      `)
      .eq("group_id", game.group_id);

    // If userId is provided, filter to that user only
    if (payload.userId) {
      recipientsQuery = recipientsQuery.eq("user_id", payload.userId);
    }

    const recipientsRes = await recipientsQuery;

    if (recipientsRes.error || !recipientsRes.data) {
      console.error(`Failed to fetch recipients: ${recipientsRes.error?.message}`);
      return jsonResponse({ error: "Failed to fetch recipients" }, 500);
    }

    const recipients = recipientsRes.data
      .map((member: any) => member.profiles)
      .filter((profile: any) => profile?.email);

    if (recipients.length === 0) {
      return jsonResponse({ error: "No recipients found" }, 400);
    }

    console.log(`Sending to ${recipients.length} recipients`);

    // Step 3: Generate RSVP tokens and send emails
    const emailPromises = recipients.map(async (profile: any) => {
      const token = generateToken();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30); // Token valid for 30 days

      // Insert or update token
      const tokenRes = await client
        .from("rsvp_tokens")
        .upsert({
          game_id: gameId,
          user_id: profile.id,
          token,
          expires_at: expiresAt.toISOString(),
        }, {
          onConflict: "game_id,user_id",
        });

      if (tokenRes.error) {
        console.error(`Failed to create token for ${profile.email}: ${tokenRes.error.message}`);
        return { email: profile.email, status: "error", error: tokenRes.error.message };
      }

      // Format game date
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

      // Generate RSVP links
      const baseUrl = supabaseUrl.replace(/\.supabase\.co$/, "");
      const goingLink = `${supabaseUrl}/functions/v1/handle-rsvp?token=${token}&status=going`;
      const maybeLink = `${supabaseUrl}/functions/v1/handle-rsvp?token=${token}&status=maybe`;
      const notGoingLink = `${supabaseUrl}/functions/v1/handle-rsvp?token=${token}&status=not_going`;

      // Send email using Resend
      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>RSVP for ${game.name}</title>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #2563eb; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }
            .game-details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
            .detail-row { margin: 10px 0; }
            .label { font-weight: bold; color: #4b5563; }
            .rsvp-buttons { text-align: center; margin: 30px 0; }
            .rsvp-button { display: inline-block; padding: 12px 30px; margin: 10px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px; }
            .btn-going { background: #10b981; color: white; }
            .btn-maybe { background: #f59e0b; color: white; }
            .btn-not-going { background: #ef4444; color: white; }
            .footer { text-align: center; color: #6b7280; font-size: 14px; margin-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🃏 ${game.name}</h1>
            </div>
            <div class="content">
              <p>Hi ${profile.first_name || "there"}!</p>
              <p>You're invited to an upcoming poker game. Please RSVP so we know you're coming!</p>

              <div class="game-details">
                <div class="detail-row"><span class="label">Group:</span> ${groupName}</div>
                <div class="detail-row"><span class="label">Date:</span> ${formattedDate}</div>
                <div class="detail-row"><span class="label">Time:</span> ${formattedTime}</div>
                ${game.location ? `<div class="detail-row"><span class="label">Location:</span> ${game.location}</div>` : ""}
                ${game.buyin_amount ? `<div class="detail-row"><span class="label">Buy-in:</span> $${game.buyin_amount}</div>` : ""}
                ${game.max_players ? `<div class="detail-row"><span class="label">Max Players:</span> ${game.max_players}</div>` : ""}
              </div>

              <div class="rsvp-buttons">
                <a href="${goingLink}" class="rsvp-button btn-going">👍 I'm Going</a>
                <a href="${maybeLink}" class="rsvp-button btn-maybe">👌 Maybe</a>
                <a href="${notGoingLink}" class="rsvp-button btn-not-going">👎 Can't Make It</a>
              </div>

              <p style="text-align: center; color: #6b7280; font-size: 14px;">
                Click one of the buttons above to RSVP. You can change your response anytime by clicking a different button.
              </p>
            </div>
            <div class="footer">
              <p>This invitation was sent by ${groupName}</p>
            </div>
          </div>
        </body>
        </html>
      `;

      // Send email using Resend API
      const emailRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: "Poker Manager <onboarding@resend.dev>", // Change to your verified domain
          to: [profile.email],
          subject: `RSVP: ${game.name} - ${formattedDate}`,
          html: emailHtml,
        }),
      });

      const emailData = await emailRes.json();

      if (!emailRes.ok) {
        console.error(`Failed to send email to ${profile.email}:`, emailData);
        return { email: profile.email, status: "error", error: emailData };
      }

      console.log(`Email sent to ${profile.email}`);
      return { email: profile.email, status: "sent", id: emailData.id };
    });

    const results = await Promise.all(emailPromises);
    const successCount = results.filter((r) => r.status === "sent").length;
    const errorCount = results.filter((r) => r.status === "error").length;

    return jsonResponse({
      status: "ok",
      sent: successCount,
      failed: errorCount,
      results,
    });
  } catch (err: any) {
    console.error("Error sending RSVP emails:", err);
    return jsonResponse({ error: err?.message ?? "Unknown error" }, 500);
  }
});
