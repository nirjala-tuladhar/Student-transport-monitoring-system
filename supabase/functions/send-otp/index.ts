import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Resend API endpoint
const RESEND_API_URL = 'https://api.resend.com/emails';

// Define reusable CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Create a Supabase client with the service role key
    const supabaseAdmin = createClient(
      Deno.env.get('PROJECT_URL') ?? '',
      Deno.env.get('SERVICE_ROLE_KEY') ?? ''
    );

    // 2. Get the Resend API key from your private table
    const { data: apiKeyData, error: apiKeyError } = await supabaseAdmin
      .from('service_keys')
      .select('key_value')
      .eq('key_name', 'resend_api_key')
      .single();

    if (apiKeyError || !apiKeyData) {
      throw new Error('Could not retrieve Resend API key from database.');
    }
    const resendApiKey = apiKeyData.key_value;

    // 3. Extract email and OTP from the request body
    const { email, otp } = await req.json();
    if (!email || !otp) {
      return new Response(JSON.stringify({ error: 'Email and OTP are required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. Construct the email payload for Resend
    const emailPayload = {
      // IMPORTANT: The 'from' address MUST use a domain you have verified in your Resend account.
      // The 'onboarding@resend.dev' address is for initial testing only.
      from: 'Student Transport <onboarding@resend.dev>',
      to: [email],
      subject: 'Your Account Invitation and OTP',
      html: `
        <div style="font-family: sans-serif; padding: 20px; color: #333;">
          <h2>Welcome!</h2>
          <p>An account has been created for you on the Student Transport Monitoring platform.</p>
          <p>Please use the following One-Time Password (OTP) for your first login:</p>
          <h1 style="font-size: 48px; letter-spacing: 5px; margin: 20px 0;">${otp}</h1>
          <p>You will be prompted to set a permanent password after logging in.</p>
          <hr/>
          <p style="font-size: 12px; color: #777;">If you did not request this, please ignore this email.</p>
        </div>
      `,
    };

    // 5. Send the email using Resend's API
    const resendResponse = await fetch(RESEND_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify(emailPayload),
    });

    if (!resendResponse.ok) {
      const errorBody = await resendResponse.json();
      console.error('Resend API Error:', JSON.stringify(errorBody, null, 2));
      throw new Error(`Failed to send email via Resend: ${errorBody.message}`);
    }

    return new Response(JSON.stringify({ message: 'OTP email sent successfully.' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
