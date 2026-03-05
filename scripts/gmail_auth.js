#!/usr/bin/env node
/**
 * Shadow AI — Gmail OAuth2 Setup
 * ================================
 * Run this ONCE to authorize Shadow AI to read and send Gmail
 * on your behalf. Saves a token.json that OpenClaw reuses.
 *
 * Usage:
 *   node gmail_auth.js
 *
 * Prerequisites:
 *   1. Go to https://console.cloud.google.com
 *   2. Create a project (or use existing)
 *   3. Enable Gmail API
 *   4. Create OAuth2 credentials (Desktop app type)
 *   5. Download credentials.json to ~/.openclaw/workspace/magicbus/gmail/
 *   6. Add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET to ~/.openclaw/openclaw.json
 *
 * npm install googleapis
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const os = require('os');

// ---- Config ------------------------------------------------------------------

const WORKSPACE = path.join(os.homedir(), '.openclaw', 'workspace', 'magicbus');
const GMAIL_DIR = path.join(WORKSPACE, 'gmail');
const TOKEN_PATH = path.join(GMAIL_DIR, 'token.json');
const CREDENTIALS_PATH = path.join(GMAIL_DIR, 'credentials.json');
const OPENCLAW_CONFIG = path.join(os.homedir(), '.openclaw', 'openclaw.json');

// Gmail scopes needed by Shadow AI
const SCOPES = [
  'https://www.googleapis.com/auth/gmail.readonly',   // Read emails
  'https://www.googleapis.com/auth/gmail.send',       // Send emails
  'https://www.googleapis.com/auth/gmail.compose',    // Compose/draft
  'https://www.googleapis.com/auth/gmail.labels',     // Read labels
];

// ---- Helpers -----------------------------------------------------------------

function log(msg) { console.log(`\x1b[32m✅ ${msg}\x1b[0m`); }
function warn(msg) { console.log(`\x1b[33m⚠️  ${msg}\x1b[0m`); }
function error(msg) { console.error(`\x1b[31m❌ ${msg}\x1b[0m`); }
function step(msg) { console.log(`\n\x1b[34m==>${\x1b[0m \x1b[32m${msg}\x1b[0m`); }

function loadOpenClawConfig() {
  try {
    return JSON.parse(fs.readFileSync(OPENCLAW_CONFIG, 'utf8'));
  } catch (e) {
    return {};
  }
}

// ---- Main --------------------------------------------------------------------

async function main() {
  console.log('\n\x1b[34m🦞 Shadow AI — Gmail OAuth Setup\x1b[0m');
  console.log('='.repeat(40));

  // Load googleapis
  let google;
  try {
    const { google: g } = require('googleapis');
    google = g;
  } catch (e) {
    error('googleapis not installed. Run: npm install googleapis');
    process.exit(1);
  }

  // Load credentials — try credentials.json first, then openclaw.json
  let clientId, clientSecret;

  if (fs.existsSync(CREDENTIALS_PATH)) {
    step('Loading credentials from credentials.json...');
    const creds = JSON.parse(fs.readFileSync(CREDENTIALS_PATH, 'utf8'));
    const { client_id, client_secret } = creds.installed || creds.web || {};
    clientId = client_id;
    clientSecret = client_secret;
    log('Loaded from credentials.json');
  } else {
    step('Loading credentials from openclaw.json...');
    const config = loadOpenClawConfig();
    clientId = config?.env?.GOOGLE_CLIENT_ID;
    clientSecret = config?.env?.GOOGLE_CLIENT_SECRET;
  }

  if (!clientId || clientId.startsWith('REPLACE') ||
      !clientSecret || clientSecret.startsWith('REPLACE')) {
    error('Google OAuth credentials not found or not configured.');
    console.log('');
    console.log('  To set up Gmail access:');
    console.log('  1. Go to https://console.cloud.google.com');
    console.log('  2. Create/select a project');
    console.log('  3. Enable Gmail API: APIs & Services -> Enable APIs -> Gmail API');
    console.log('  4. Create credentials: APIs & Services -> Credentials -> OAuth 2.0');
    console.log('     -> Application type: Desktop app');
    console.log('  5. Download JSON and save to:');
    console.log(`     ${CREDENTIALS_PATH}`);
    console.log('  OR add to ~/.openclaw/openclaw.json:');
    console.log('     "GOOGLE_CLIENT_ID": "your_client_id"');
    console.log('     "GOOGLE_CLIENT_SECRET": "your_client_secret"');
    process.exit(1);
  }

  log(`Client ID loaded: ${clientId.substring(0, 20)}...`);

  // Check if already authorized
  if (fs.existsSync(TOKEN_PATH)) {
    warn('token.json already exists. To re-authorize, delete it first:');
    warn(`  rm ${TOKEN_PATH}`);
    console.log('');
    log('Gmail is already authorized for Shadow AI!');
    testGmailAccess(google, clientId, clientSecret);
    return;
  }

  // Create OAuth2 client
  const oauth2Client = new google.auth.OAuth2(
    clientId,
    clientSecret,
    'urn:ietf:wg:oauth:2.0:oob'  // Desktop app redirect
  );

  // Generate auth URL
  step('Generating authorization URL...');
  const authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
    prompt: 'consent',  // Force consent to get refresh token
  });

  console.log('');
  console.log('\x1b[33m🔗 Open this URL in your browser to authorize Gmail access:\x1b[0m');
  console.log('');
  console.log(`  ${authUrl}`);
  console.log('');

  // Get authorization code from user
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question('  Paste the authorization code here: ', async (code) => {
    rl.close();
    try {
      step('Exchanging code for access token...');
      const { tokens } = await oauth2Client.getToken(code.trim());
      oauth2Client.setCredentials(tokens);

      // Save token
      fs.mkdirSync(GMAIL_DIR, { recursive: true });
      fs.writeFileSync(TOKEN_PATH, JSON.stringify(tokens, null, 2));
      log(`Token saved to ${TOKEN_PATH}`);

      // Verify by listing labels
      step('Verifying Gmail access...');
      const gmail = google.gmail({ version: 'v1', auth: oauth2Client });
      const res = await gmail.users.labels.list({ userId: 'me' });
      const labels = res.data.labels || [];
      log(`Gmail connected! Found ${labels.length} labels.`);

      // Get inbox count
      const inbox = await gmail.users.messages.list({
        userId: 'me',
        labelIds: ['INBOX'],
        maxResults: 1,
      });
      const total = inbox.data.resultSizeEstimate || 0;
      log(`Inbox accessible. ~${total} messages found.`);

      console.log('');
      console.log('\x1b[32m' + '='.repeat(40) + '\x1b[0m');
      console.log('\x1b[32m🦞 Gmail OAuth Setup Complete!\x1b[0m');
      console.log('\x1b[32m' + '='.repeat(40) + '\x1b[0m');
      console.log('');
      console.log('  Shadow AI can now:');
      console.log('  ✅ Read your Gmail inbox');
      console.log('  ✅ Draft and send emails (with your approval)');
      console.log('  ✅ Monitor Magic Bus emails automatically');
      console.log('');
      console.log('  Start OpenClaw and say: "check my inbox"');
      console.log('');

    } catch (err) {
      error(`Failed to get token: ${err.message}`);
      console.log('  Make sure you copied the full authorization code.');
      process.exit(1);
    }
  });
}

async function testGmailAccess(google, clientId, clientSecret) {
  try {
    const tokens = JSON.parse(fs.readFileSync(TOKEN_PATH, 'utf8'));
    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);
    oauth2Client.setCredentials(tokens);
    const gmail = google.gmail({ version: 'v1', auth: oauth2Client });
    const res = await gmail.users.getProfile({ userId: 'me' });
    log(`Connected as: ${res.data.emailAddress}`);
    log(`Total messages: ${res.data.messagesTotal}`);
  } catch (e) {
    warn(`Could not verify existing token: ${e.message}`);
  }
}

main().catch(console.error);
