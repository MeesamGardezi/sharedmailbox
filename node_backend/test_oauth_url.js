
require('dotenv').config();
const msal = require('@azure/msal-node');

const MICROSOFT_SCOPES = [
    'openid',
    'profile',
    'email',
    'offline_access',
    'https://graph.microsoft.com/Mail.Read',
    'https://graph.microsoft.com/Mail.ReadWrite',
    'https://graph.microsoft.com/Calendars.Read',
    'https://graph.microsoft.com/User.Read'
];

const msalConfig = {
    auth: {
        clientId: process.env.MICROSOFT_CLIENT_ID || 'fake_client_id',
        authority: process.env.MICROSOFT_AUTHORITY || 'https://login.microsoftonline.com/common',
        clientSecret: process.env.MICROSOFT_CLIENT_SECRET || 'fake_secret',
    }
};

const msalClient = new msal.ConfidentialClientApplication(msalConfig);
const MICROSOFT_REDIRECT_URI = process.env.MICROSOFT_REDIRECT_URI || 'https://api.mybox.buildersolve.com/auth/microsoft/callback';

async function test() {
    console.log('--- Config ---');
    console.log('Redirect URI:', MICROSOFT_REDIRECT_URI);
    console.log('Client ID:', msalConfig.auth.clientId);
    console.log('Authority:', msalConfig.auth.authority);

    const authUrlParameters = {
        scopes: MICROSOFT_SCOPES,
        redirectUri: MICROSOFT_REDIRECT_URI.trim(),
        state: 'test_state',
        prompt: 'consent'
    };

    try {
        const authUrl = await msalClient.getAuthCodeUrl(authUrlParameters);
        console.log('\n--- Generated URL ---');
        console.log(authUrl);

        if (authUrl.includes('redirect_uri=')) {
            console.log('\nSUCCESS: redirect_uri is present in the URL.');
        } else {
            console.log('\nFAILURE: redirect_uri is MISSING from the URL.');
        }
    } catch (error) {
        console.error('Error generating URL:', error);
    }
}

test();
