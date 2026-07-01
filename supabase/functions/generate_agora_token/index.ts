import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

// ---------------------------------------------------------------------------
// Agora AccessToken2 builder
// Reference: https://github.com/AgoraIO/Tools/tree/master/DynamicKey/AgoraDynamicKey
//
// Token format: "007" + base64( HMAC-SHA256(body) + body )
// Body: appId + expire + salt + issueTs + services
// ---------------------------------------------------------------------------

function concat(...arrays: Uint8Array[]): Uint8Array {
  const total = arrays.reduce((s, a) => s + a.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const a of arrays) { out.set(a, offset); offset += a.length; }
  return out;
}

// Agora uses little-endian packing
function p16(v: number): Uint8Array {
  return new Uint8Array([v & 0xff, (v >> 8) & 0xff]);
}

function p32(v: number): Uint8Array {
  return new Uint8Array([
    v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff,
  ]);
}

function pStr(s: string): Uint8Array {
  const enc = new TextEncoder().encode(s);
  return concat(p16(enc.length), enc);
}

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

// Privilege types for ServiceRtc
const PRIV_JOIN = 1;
const PRIV_PUB_AUDIO = 2;
const PRIV_PUB_VIDEO = 3;
const PRIV_PUB_DATA = 4;

async function buildRtcToken(
  appId: string,
  appCertificate: string,
  channelName: string,
  uid: number,
  tokenExpireSecs: number,
  privilegeExpireSecs: number,
): Promise<string> {
  const salt = Math.floor(Math.random() * 0xffffffff) + 1;
  const issueTs = Math.floor(Date.now() / 1000);
  const expire = issueTs + tokenExpireSecs;
  const privExpire = issueTs + privilegeExpireSecs;
  const uidStr = uid === 0 ? '' : String(uid);

  // Pack privileges: [1=join, 2=pub_audio, 3=pub_video, 4=pub_data]
  const privs: [number, number][] = [
    [PRIV_JOIN, privExpire],
    [PRIV_PUB_AUDIO, privExpire],
    [PRIV_PUB_VIDEO, privExpire],
    [PRIV_PUB_DATA, privExpire],
  ];

  // ServiceRtc body: type + privileges + channelName + uid
  const serviceBody = concat(
    p16(1),              // service type = RTC (1)
    p16(privs.length),
    ...privs.flatMap(([t, e]) => [p16(t), p32(e)]),
    pStr(channelName),
    pStr(uidStr),
  );

  // Main body: appId + expire + salt + issueTs + num_services + service
  const body = concat(
    pStr(appId),
    p32(expire),
    p32(salt),
    p32(issueTs),
    p16(1),              // 1 service
    serviceBody,
  );

  // HMAC-SHA256 signature over body, keyed with appCertificate bytes
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(appCertificate),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, body));

  // Token = "007" + base64(signature + body)
  return '007' + toBase64(concat(sig, body));
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const appId = Deno.env.get('AGORA_APP_ID') ?? '';
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE') ?? '';

    if (!appId) {
      return new Response(
        JSON.stringify({ error: 'AGORA_APP_ID not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { channelName, uid = 0 } = await req.json();

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: 'channelName is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // If no certificate configured → test mode (no token needed, Agora console
    // must have "Testing Mode" enabled with no certificate). Return null so the
    // Flutter client connects with an empty token string.
    if (!appCertificate) {
      return new Response(
        JSON.stringify({ appId, token: null, channelName }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const TOKEN_EXPIRE_SECS = 3600;    // 1 hour
    const PRIV_EXPIRE_SECS = 3600;

    const token = await buildRtcToken(
      appId,
      appCertificate,
      channelName,
      uid,
      TOKEN_EXPIRE_SECS,
      PRIV_EXPIRE_SECS,
    );

    return new Response(
      JSON.stringify({ appId, token, channelName }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
