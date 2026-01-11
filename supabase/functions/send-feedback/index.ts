// Send feedback email from app users to the developer
// Uses Resend API for email delivery (or any configured SMTP/email service)
// Requires DEVELOPER_EMAIL and RESEND_API_KEY in the function environment.

import { serve } from "std/http/server.ts";

const developerEmail = Deno.env.get("DEVELOPER_EMAIL") || "support@pokermanager.app";
const resendApiKey = Deno.env.get("RESEND_API_KEY");

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let payload: {
    category?: string;
    feedback?: string;
    userEmail?: string;
    appName?: string;
    developerEmail?: string;
  };

  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const category = payload.category?.trim() ?? "General Feedback";
  const feedback = payload.feedback?.trim();
  const userEmail = payload.userEmail?.trim() ?? "anonymous";
  const appName = payload.appName?.trim() ?? "Poker Manager";
  const targetEmail = payload.developerEmail?.trim() ?? developerEmail;

  if (!feedback) {
    return jsonResponse({ error: "feedback is required" }, 400);
  }

  const subject = `[${category}] ${appName} Feedback`;
  const htmlBody = `
    <h2>${category}</h2>
    <p><strong>From:</strong> ${userEmail}</p>
    <p><strong>App:</strong> ${appName}</p>
    <hr />
    <p>${feedback.replace(/\n/g, "<br />")}</p>
    <hr />
    <p style="color: #666; font-size: 12px;">
      This feedback was submitted via the ${appName} app.
    </p>
  `;

  const textBody = `
${category}
From: ${userEmail}
App: ${appName}
---
${feedback}
---
This feedback was submitted via the ${appName} app.
  `.trim();

  try {
    // If Resend API key is configured, send via Resend
    if (resendApiKey) {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: `${appName} Feedback <feedback@pokermanager.app>`,
          to: [targetEmail],
          reply_to: userEmail !== "anonymous" ? userEmail : undefined,
          subject: subject,
          html: htmlBody,
          text: textBody,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        console.error("Resend API error:", errorData);
        return jsonResponse({ error: "Failed to send email", details: errorData }, 500);
      }

      const result = await response.json();
      console.log(`Feedback sent successfully. Email ID: ${result.id}`);
      return jsonResponse({ status: "ok", emailId: result.id });
    }

    // Fallback: Log feedback to console if no email service configured
    // In production, you would configure an email service
    console.log("=== FEEDBACK RECEIVED ===");
    console.log(`Category: ${category}`);
    console.log(`From: ${userEmail}`);
    console.log(`To: ${targetEmail}`);
    console.log(`Subject: ${subject}`);
    console.log(`Feedback: ${feedback}`);
    console.log("========================");

    // Return success - feedback was logged even if not emailed
    return jsonResponse({
      status: "ok",
      message: "Feedback received (email service not configured - logged only)"
    });

  } catch (err) {
    console.error("Error sending feedback:", err);
    return jsonResponse({ error: err?.message ?? "Unknown error" }, 500);
  }
});
