import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "GET") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers });
  }
  // verify_jwt=true enforces the platform's JWT validation before this handler runs.
  return new Response(JSON.stringify({
    app: "SHIFT",
    backend: "online",
    data_sync: "available_for_authenticated_clients",
    social_oauth: false,
    ai_generation: false,
    trend_research: false,
    image_generation: false,
    provider_analytics: false,
    scheduled_publishing: false,
    autopilot: false,
    notifications: "database_only",
  }), { headers });
});
