// Supabase Edge Function: creates a Stripe PaymentIntent and returns its
// client secret. Runs server-side so the Stripe *secret* key never ships
// inside the iOS app (only the publishable key does, same trust model as
// the Supabase anon key). Talks to Stripe's REST API directly with fetch
// instead of the stripe npm package, since that keeps this function
// dependency-free and easy to paste straight into the Supabase dashboard.
//
// Deploy: Supabase Dashboard -> Edge Functions -> Deploy a new function
// (name it exactly "create-payment-intent"), paste this file's contents.
// Requires the STRIPE_SECRET_KEY secret to already be set under
// Project Settings -> Edge Functions -> Secrets.
import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!STRIPE_SECRET_KEY) {
    return new Response(JSON.stringify({ error: "STRIPE_SECRET_KEY is not configured on the server" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { amount, currency, description } = await req.json();

    if (!Number.isInteger(amount) || amount <= 0) {
      return new Response(JSON.stringify({ error: "amount must be a positive integer (in cents)" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = new URLSearchParams({
      amount: String(amount),
      currency: typeof currency === "string" && currency.length > 0 ? currency : "usd",
      "automatic_payment_methods[enabled]": "true",
      description: typeof description === "string" && description.length > 0 ? description : "core. payment",
    });

    const stripeResponse = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    });

    const paymentIntent = await stripeResponse.json();

    if (!stripeResponse.ok) {
      return new Response(JSON.stringify({ error: paymentIntent.error?.message ?? "Stripe error" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ clientSecret: paymentIntent.client_secret }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
