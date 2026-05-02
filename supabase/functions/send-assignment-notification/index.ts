// supabase/functions/send-assignment-notification/index.ts
//
// Wird vom Database-Webhook getriggert wenn eine neue Zeile in
// `course_assignments` eingefügt wird. Lädt Kurs-Details + alle device_tokens
// des betroffenen Instructors und sendet eine APNs-Push.
//
// Secrets (zu setzen via `supabase secrets set ...`):
//   APNS_AUTH_KEY     — der Inhalt der .p8 Datei (PEM, mit -----BEGIN PRIVATE KEY-----)
//   APNS_KEY_ID       — 10 Zeichen, vom Apple Developer Portal
//   APNS_TEAM_ID      — 10 Zeichen, oben rechts in Apple Developer
//   APNS_BUNDLE_ID    — z.B. "swiss.atoll.app"
//   APNS_ENVIRONMENT  — "sandbox" (default, für Xcode-Builds) oder "production" (TestFlight/App Store)
//
// Database-Webhook URL kommt automatisch via SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0"
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6"

interface DatabaseWebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE"
  table: string
  record: {
    id: string
    instructor_id: string
    course_id: string
    role: string
    confirmed: boolean
  } | null
  old_record?: unknown
}

serve(async (req) => {
  try {
    const payload = (await req.json()) as DatabaseWebhookPayload

    // Nur INSERTs auf course_assignments behandeln
    if (payload.type !== "INSERT" || !payload.record) {
      return jsonResponse({ skipped: true, reason: "not an insert" })
    }
    const { instructor_id, course_id, id: assignment_id, role } = payload.record

    // Supabase-Client mit Service-Role
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    // Kurs-Details laden
    const { data: course, error: courseErr } = await supa
      .from("courses")
      .select("title, start_date, course_types(code, label)")
      .eq("id", course_id)
      .single()
    if (courseErr || !course) {
      return jsonResponse({ error: "course not found", details: courseErr }, 404)
    }

    // Device-Tokens des Instructors
    const { data: tokens, error: tokenErr } = await supa
      .from("device_tokens")
      .select("apns_token, platform")
      .eq("instructor_id", instructor_id)
      .eq("platform", "ios")
    if (tokenErr) {
      return jsonResponse({ error: "token query failed", details: tokenErr }, 500)
    }
    if (!tokens || tokens.length === 0) {
      return jsonResponse({ sent: 0, reason: "no devices registered" })
    }

    // APNs-JWT generieren
    const jwt = await buildApnsJwt()

    // Notification-Body bauen
    const startDate = new Date(course.start_date).toLocaleDateString("de-CH", {
      day: "numeric",
      month: "long",
    })
    const ctype = (course.course_types as { code?: string; label?: string } | null)
    const apnsPayload = {
      aps: {
        alert: {
          title: "Neue Zuteilung 🤿",
          body: `${ctype?.code ? `${ctype.code}: ` : ""}${course.title} am ${startDate}`,
        },
        sound: "default",
        "thread-id": "assignments",
        badge: 1,
      },
      assignment_id,
      course_id,
      role,
    }

    // Push-Senden
    const env = (Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox").toLowerCase()
    const host = env === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com"
    const bundleId = Deno.env.get("APNS_BUNDLE_ID")!

    const results = await Promise.all(
      tokens.map(async (t) => {
        const url = `https://${host}/3/device/${t.apns_token}`
        const res = await fetch(url, {
          method: "POST",
          headers: {
            "authorization": `bearer ${jwt}`,
            "apns-topic": bundleId,
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          body: JSON.stringify(apnsPayload),
        })
        const text = await res.text()
        return {
          token: t.apns_token.slice(0, 12) + "…",
          status: res.status,
          body: text || "(empty)",
        }
      }),
    )

    return jsonResponse({
      sent: results.length,
      environment: env,
      results,
    })
  } catch (err) {
    console.error("send-assignment-notification error:", err)
    return jsonResponse({ error: String(err) }, 500)
  }
})

// =============================================================
// Helpers
// =============================================================

async function buildApnsJwt(): Promise<string> {
  const pem = Deno.env.get("APNS_AUTH_KEY")!
  const keyId = Deno.env.get("APNS_KEY_ID")!
  const teamId = Deno.env.get("APNS_TEAM_ID")!

  const privateKey = await importPKCS8(pem, "ES256")

  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey)
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
