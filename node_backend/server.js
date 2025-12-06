require('dotenv').config();
const express = require('express');
const { google } = require('googleapis');
const imaps = require('imap-simple');
const simpleParser = require('mailparser').simpleParser;
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account file in same directory
const serviceAccount = require('./firebase-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'mailautomation-1'
    });
}
const db = admin.firestore();

const app = express();
const port = process.env.PORT || 3000;

// CORS configuration - restrict to frontend domain in production
app.use(cors({
    origin: true, // Allow all origins
    credentials: true
}));

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ============================================================================
// GOOGLE OAUTH CONFIGURATION
// ============================================================================

const SCOPES = [
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/calendar.readonly'
];

const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI || `http://localhost:${port}/auth/google/callback`
);

// ============================================================================
// MICROSOFT OAUTH CONFIGURATION
// ============================================================================

const msal = require('@azure/msal-node');
const axios = require('axios');

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
        clientId: process.env.MICROSOFT_CLIENT_ID,
        authority: process.env.MICROSOFT_AUTHORITY || 'https://login.microsoftonline.com/common',
        clientSecret: process.env.MICROSOFT_CLIENT_SECRET,
    }
};

const msalClient = new msal.ConfidentialClientApplication(msalConfig);
const MICROSOFT_REDIRECT_URI = process.env.MICROSOFT_REDIRECT_URI || `http://localhost:${port}/auth/microsoft/callback`;

// ============================================================================
// OAUTH ROUTES
// ============================================================================

/**
 * GET /auth/google
 * Initiate Google OAuth flow
 * Query params: companyId, userId
 */
app.get('/auth/google', (req, res) => {
    const { companyId, userId } = req.query;

    if (!companyId || !userId) {
        return res.status(400).send('Missing companyId or userId');
    }

    // Encode state to pass through OAuth flow
    const state = Buffer.from(JSON.stringify({ companyId, userId })).toString('base64');

    const authUrl = oauth2Client.generateAuthUrl({
        access_type: 'offline', // Required to get refresh token
        scope: SCOPES,
        state: state,
        prompt: 'consent' // Force consent to ensure we get a refresh token
    });

    res.redirect(authUrl);
});

/**
 * GET /auth/google/callback
 * Handle OAuth callback
 */
app.get('/auth/google/callback', async (req, res) => {
    const { code, state } = req.query;

    if (!code || !state) {
        return res.status(400).send('Missing code or state');
    }

    try {
        // Decode state
        const { companyId, userId } = JSON.parse(Buffer.from(state, 'base64').toString());

        // Exchange code for tokens
        const { tokens } = await oauth2Client.getToken(code);
        oauth2Client.setCredentials(tokens);

        // Get user profile to get email address
        const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();
        const email = userInfo.data.email;

        // Save account to Firestore
        const accountData = {
            companyId,
            addedBy: userId,
            name: email, // Use email as default name
            email: email,
            provider: 'gmail-oauth',
            status: 'active',
            oauth: {
                accessToken: tokens.access_token,
                refreshToken: tokens.refresh_token,
                expiryDate: tokens.expiry_date,
                scope: tokens.scope,
                tokenType: tokens.token_type
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        // Check if account already exists
        const existingAccount = await db.collection('emailAccounts')
            .where('companyId', '==', companyId)
            .where('email', '==', email)
            .get();

        if (!existingAccount.empty) {
            // Update existing account
            await existingAccount.docs[0].ref.update({
                ...accountData,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // Create new account
            await db.collection('emailAccounts').add(accountData);
        }

        // Return success page that redirects to frontend
        const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:8080';
        res.send(`
            <html>
                <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background-color: #f5f7fa;">
                    <div style="background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center;">
                        <h1 style="color: #4f46e5; margin-bottom: 16px;">Authentication Successful!</h1>
                        <p style="color: #4b5563; margin-bottom: 24px;">Your Gmail account has been connected successfully.</p>
                        <p style="color: #6b7280; font-size: 14px;">You can close this window and return to the app.</p>
                        <script>
                            // Try to close the window automatically after 3 seconds
                            setTimeout(() => {
                                window.close();
                            }, 3000);
                        </script>
                    </div>
                </body>
            </html>
        `);

    } catch (error) {
        console.error('OAuth Error:', error);
        res.status(500).send(`Authentication failed: ${error.message}`);
    }
});

// ============================================================================
// MICROSOFT OAUTH ROUTES
// ============================================================================

/**
 * GET /auth/microsoft
 * Initiate Microsoft OAuth flow
 * Query params: companyId, userId
 */
app.get('/auth/microsoft', async (req, res) => {
    const { companyId, userId } = req.query;

    if (!companyId || !userId) {
        return res.status(400).send('Missing companyId or userId');
    }

    // Encode state to pass through OAuth flow
    const state = Buffer.from(JSON.stringify({ companyId, userId })).toString('base64');

    const authUrlParameters = {
        scopes: MICROSOFT_SCOPES,
        redirectUri: MICROSOFT_REDIRECT_URI,
        state: state,
        prompt: 'consent'
    };

    try {
        const authUrl = await msalClient.getAuthCodeUrl(authUrlParameters);
        res.redirect(authUrl);
    } catch (error) {
        console.error('Microsoft OAuth Error:', error);
        res.status(500).send(`Failed to initiate Microsoft OAuth: ${error.message}`);
    }
});

/**
 * GET /auth/microsoft/callback
 * Handle Microsoft OAuth callback
 */
app.get('/auth/microsoft/callback', async (req, res) => {
    const { code, state, error, error_description } = req.query;

    if (error) {
        console.error('Microsoft OAuth Error:', error, error_description);
        return res.status(400).send(`Authentication failed: ${error_description}`);
    }

    if (!code || !state) {
        return res.status(400).send('Missing code or state');
    }

    try {
        // Decode state
        const { companyId, userId } = JSON.parse(Buffer.from(state, 'base64').toString());

        // Exchange code for tokens
        const tokenRequest = {
            code: code,
            scopes: MICROSOFT_SCOPES,
            redirectUri: MICROSOFT_REDIRECT_URI
        };

        const tokenResponse = await msalClient.acquireTokenByCode(tokenRequest);

        console.log('[Microsoft] Token acquired successfully');

        // Get user profile from Microsoft Graph
        const userResponse = await axios.get('https://graph.microsoft.com/v1.0/me', {
            headers: {
                'Authorization': `Bearer ${tokenResponse.accessToken}`
            }
        });

        const email = userResponse.data.mail || userResponse.data.userPrincipalName;
        const displayName = userResponse.data.displayName || email;

        console.log('[Microsoft] User info:', { email, displayName });

        // Save account to Firestore
        const accountData = {
            companyId,
            addedBy: userId,
            name: displayName,
            email: email,
            provider: 'microsoft-oauth',
            status: 'active',
            oauth: {
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.account?.homeAccountId ? tokenResponse.account.homeAccountId : null,
                expiryDate: tokenResponse.expiresOn ? tokenResponse.expiresOn.getTime() : null,
                scope: MICROSOFT_SCOPES.join(' '),
                tokenType: 'Bearer',
                idToken: tokenResponse.idToken,
                accountId: tokenResponse.account?.homeAccountId
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        // Check if account already exists
        const existingAccount = await db.collection('emailAccounts')
            .where('companyId', '==', companyId)
            .where('email', '==', email)
            .get();

        if (!existingAccount.empty) {
            // Update existing account
            await existingAccount.docs[0].ref.update({
                ...accountData,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // Create new account
            await db.collection('emailAccounts').add(accountData);
        }

        // Return success page
        const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:8080';
        res.send(`
            <html>
                <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background-color: #f5f7fa;">
                    <div style="background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center;">
                        <h1 style="color: #0078d4; margin-bottom: 16px;">Authentication Successful!</h1>
                        <p style="color: #4b5563; margin-bottom: 24px;">Your Microsoft account has been connected successfully.</p>
                        <p style="color: #6b7280; font-size: 14px;">You can close this window and return to the app.</p>
                        <script>
                            setTimeout(() => {
                                window.close();
                            }, 3000);
                        </script>
                    </div>
                </body>
            </html>
        `);

    } catch (error) {
        console.error('Microsoft OAuth Callback Error:', error);
        res.status(500).send(`Authentication failed: ${error.message}`);
    }
});

/**
 * Refresh Microsoft access token
 */
async function refreshMicrosoftToken(account, forceRefresh = false) {
    let expiryDate = account.oauth.expiryDate;

    // Handle Firestore Timestamp objects
    if (expiryDate && typeof expiryDate === 'object' && expiryDate._seconds) {
        expiryDate = expiryDate._seconds * 1000;
    }

    const shouldRefresh = forceRefresh || !expiryDate || Date.now() >= expiryDate - 60000;

    console.log('[Microsoft Token] Checking token:', {
        hasAccountId: !!account.oauth.accountId,
        expiryDate: expiryDate ? new Date(expiryDate).toISOString() : 'none',
        shouldRefresh,
        forceRefresh
    });

    if (shouldRefresh && account.oauth.accountId) {
        console.log('[Microsoft] Refreshing access token...');
        try {
            // Get the account from MSAL cache or create a silent request
            const silentRequest = {
                scopes: MICROSOFT_SCOPES,
                account: {
                    homeAccountId: account.oauth.accountId
                }
            };

            // Try to acquire token silently (from cache or refresh)
            // Note: This might fail if token cache isn't persistent
            // In that case, user needs to re-authenticate
            const tokenResponse = await msalClient.acquireTokenSilent(silentRequest);

            console.log('[Microsoft] Token refreshed successfully');

            return {
                accessToken: tokenResponse.accessToken,
                expiryDate: tokenResponse.expiresOn ? tokenResponse.expiresOn.getTime() : null,
                accountId: account.oauth.accountId,
                refreshed: true
            };
        } catch (err) {
            console.error('[Microsoft] Token refresh failed:', err.message);
            // Return existing token as fallback (it might still work)
            return {
                accessToken: account.oauth.accessToken,
                expiryDate: expiryDate,
                accountId: account.oauth.accountId,
                refreshed: false,
                error: err.message
            };
        }
    }

    return {
        accessToken: account.oauth.accessToken,
        expiryDate: expiryDate,
        accountId: account.oauth.accountId,
        refreshed: false
    };
}

/**
 * Fetch emails from Microsoft/Outlook using Graph API
 */
async function fetchEmailsFromMicrosoft(account, skipToken = null) {
    console.log(`[Microsoft] Fetching emails for ${account.email}...`);

    try {
        const tokenInfo = await refreshMicrosoftToken(account);

        let url = 'https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages?$top=20&$orderby=receivedDateTime desc&$select=id,subject,bodyPreview,body,from,toRecipients,receivedDateTime,isRead,conversationId';

        if (skipToken) {
            url = skipToken; // Microsoft Graph uses full URL as skip token
        }

        const response = await axios.get(url, {
            headers: {
                'Authorization': `Bearer ${tokenInfo.accessToken}`,
                'Content-Type': 'application/json'
            }
        });

        const messages = response.data.value || [];
        const nextLink = response.data['@odata.nextLink'];

        console.log(`[Microsoft] Fetched ${messages.length} messages`);

        const emails = messages.map(msg => ({
            id: `microsoft_${account.email}_${msg.id}`,
            messageId: msg.id,
            threadId: msg.conversationId,
            accountName: account.name || account.email,
            accountType: 'microsoft',
            subject: msg.subject || '(No Subject)',
            from: msg.from?.emailAddress ? `${msg.from.emailAddress.name || ''} <${msg.from.emailAddress.address}>` : 'Unknown',
            to: msg.toRecipients?.map(r => r.emailAddress?.address).join(', ') || '',
            date: new Date(msg.receivedDateTime),
            text: msg.bodyPreview || '',
            html: msg.body?.content || '',
            isRead: msg.isRead,
            snippet: (msg.bodyPreview || '').substring(0, 200)
        }));

        return {
            emails,
            nextPageToken: nextLink,
            tokenInfo
        };

    } catch (err) {
        console.error(`[Microsoft] Error fetching emails:`, err.message);
        if (err.response) {
            console.error('[Microsoft] Response status:', err.response.status);
            console.error('[Microsoft] Response data:', JSON.stringify(err.response.data, null, 2));
        }
        return { emails: [], nextPageToken: null, tokenInfo: null };
    }
}

/**
 * Fetch calendar events from Microsoft/Outlook using Graph API
 */
async function fetchCalendarEventsFromMicrosoft(account, timeMin, timeMax) {
    console.log(`[Microsoft Calendar] Fetching events for ${account.email}...`);

    try {
        const tokenInfo = await refreshMicrosoftToken(account, true);

        const response = await axios.get('https://graph.microsoft.com/v1.0/me/calendar/calendarView', {
            headers: {
                'Authorization': `Bearer ${tokenInfo.accessToken}`,
                'Content-Type': 'application/json'
            },
            params: {
                startDateTime: timeMin,
                endDateTime: timeMax,
                $top: 50,
                $orderby: 'start/dateTime',
                $select: 'id,subject,bodyPreview,start,end,location,organizer,attendees,isAllDay'
            }
        });

        const events = response.data.value || [];
        console.log(`[Microsoft Calendar] Fetched ${events.length} events`);

        // Transform to a common format similar to Google Calendar
        return {
            events: events.map(event => ({
                id: event.id,
                summary: event.subject,
                description: event.bodyPreview,
                start: {
                    dateTime: event.start?.dateTime,
                    timeZone: event.start?.timeZone
                },
                end: {
                    dateTime: event.end?.dateTime,
                    timeZone: event.end?.timeZone
                },
                location: event.location?.displayName,
                organizer: {
                    email: event.organizer?.emailAddress?.address,
                    displayName: event.organizer?.emailAddress?.name
                },
                attendees: event.attendees?.map(a => ({
                    email: a.emailAddress?.address,
                    displayName: a.emailAddress?.name,
                    responseStatus: a.status?.response
                })),
                source: 'microsoft'
            })),
            tokenInfo
        };

    } catch (err) {
        console.error(`[Microsoft Calendar] Error:`, err.message);
        if (err.response) {
            console.error('[Microsoft Calendar] Response status:', err.response.status);
            console.error('[Microsoft Calendar] Response data:', JSON.stringify(err.response.data, null, 2));
        }
        return { events: [], tokenInfo: null };
    }
}

// ============================================================================
// IMAP CONFIGURATION
// ============================================================================

// Fallback config from .env (for backward compatibility)
const fallbackConfig = {
    imap: {
        user: process.env.IMAP_USER,
        password: process.env.IMAP_PASSWORD,
        host: process.env.IMAP_HOST,
        port: process.env.IMAP_PORT || 993,
        tls: process.env.IMAP_TLS === 'true',
        tlsOptions: { rejectUnauthorized: false },
        authTimeout: 3000
    }
};

/**
 * Fetch emails from a single IMAP account
 * Uses sequence numbers to fetch only the last 20 emails
 */
async function fetchEmailsFromAccount(accountConfig, accountName = 'Default') {
    console.log(`[${accountName}] Attempting to connect to ${accountConfig.host}:${accountConfig.port}...`);

    const timeout = (ms) => new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Operation timed out')), ms)
    );

    try {
        // Add 10 second timeout for connection
        const connection = await Promise.race([
            imaps.connect({ imap: accountConfig }),
            timeout(10000)
        ]);
        console.log(`[${accountName}] Connected. Opening INBOX...`);

        const box = await connection.openBox('INBOX');
        const totalMessages = box.messages.total;
        console.log(`[${accountName}] INBOX opened. Total messages: ${totalMessages}`);

        if (totalMessages === 0) {
            connection.end();
            return [];
        }

        // Calculate the sequence range for the last 20 messages
        const startSeq = Math.max(1, totalMessages - 19);
        const endSeq = totalMessages;
        const searchCriteria = [`${startSeq}:${endSeq}`];

        console.log(`[${accountName}] Fetching messages ${startSeq} to ${endSeq}...`);

        const fetchOptions = {
            bodies: ['HEADER', 'TEXT', ''],
            markSeen: false,
            struct: true
        };

        const messages = await Promise.race([
            connection.search(searchCriteria, fetchOptions),
            timeout(20000)
        ]);

        console.log(`[${accountName}] Fetched ${messages.length} messages.`);

        const emails = await Promise.all(messages.reverse().map(async (item) => {
            const all = item.parts.find(part => part.which === '');
            const id = item.attributes.uid;
            const idHeader = "Imap-Id: " + id + "\r\n";

            try {
                const parsed = await simpleParser(idHeader + all.body);
                return {
                    id: `imap_${accountName}_${id}`,
                    uid: id,
                    messageId: parsed.messageId || `${id}@${accountConfig.host}`,
                    threadId: parsed.inReplyTo || parsed.messageId || `${id}`,
                    accountName: accountName,
                    accountType: 'imap',
                    subject: parsed.subject || '(No Subject)',
                    from: parsed.from ? parsed.from.text : 'Unknown',
                    to: parsed.to ? parsed.to.text : '',
                    date: parsed.date || new Date(),
                    text: parsed.text || '',
                    html: parsed.html || parsed.textAsHtml || '',
                    isRead: item.attributes.flags && item.attributes.flags.includes('\\Seen'),
                    snippet: (parsed.text || '').substring(0, 200)
                };
            } catch (err) {
                console.error(`[${accountName}] Error parsing email ${id}:`, err);
                return {
                    id: `imap_${accountName}_${id}`,
                    uid: id,
                    messageId: `${id}@${accountConfig.host}`,
                    threadId: `${id}`,
                    accountName: accountName,
                    accountType: 'imap',
                    subject: 'Error parsing email',
                    from: 'Unknown',
                    to: '',
                    date: new Date(),
                    text: 'Error parsing email content',
                    html: '<div>Error parsing email content</div>',
                    isRead: false,
                    snippet: 'Error parsing email content'
                };
            }
        }));

        connection.end();
        return emails;
    } catch (err) {
        console.error(`[${accountName}] Error:`, err.message || err);
        return [];
    }
}

/**
 * Refresh Gmail access token if expired
 * FIXED: Now properly creates a new OAuth2 client instance for each request
 */
async function refreshGmailToken(account, forceRefresh = false) {
    let expiryDate = account.oauth.expiryDate;

    // Handle Firestore Timestamp objects
    if (expiryDate && typeof expiryDate === 'object' && expiryDate._seconds) {
        expiryDate = expiryDate._seconds * 1000;
    }

    const shouldRefresh = forceRefresh || !expiryDate || Date.now() >= expiryDate - 60000;

    console.log('[Token] Checking token:', {
        hasRefreshToken: !!account.oauth.refreshToken,
        expiryDate: expiryDate ? new Date(expiryDate).toISOString() : 'none',
        shouldRefresh,
        forceRefresh
    });

    if (shouldRefresh && account.oauth.refreshToken) {
        console.log('[Gmail] Refreshing access token...');
        try {
            // Create a fresh OAuth2 client for the refresh
            const refreshClient = new google.auth.OAuth2(
                process.env.GOOGLE_CLIENT_ID,
                process.env.GOOGLE_CLIENT_SECRET,
                process.env.GOOGLE_REDIRECT_URI || `http://localhost:${port}/auth/google/callback`
            );

            refreshClient.setCredentials({
                refresh_token: account.oauth.refreshToken
            });

            const { credentials } = await refreshClient.refreshAccessToken();

            console.log('[Gmail] Token refreshed successfully:', {
                hasAccessToken: !!credentials.access_token,
                newExpiry: credentials.expiry_date ? new Date(credentials.expiry_date).toISOString() : 'none'
            });

            return {
                accessToken: credentials.access_token,
                expiryDate: credentials.expiry_date,
                refreshToken: account.oauth.refreshToken, // Keep the refresh token
                refreshed: true
            };
        } catch (err) {
            console.error('[Gmail] Token refresh failed:', err.message);
            console.error('[Gmail] Full refresh error:', JSON.stringify(err.response?.data || err, null, 2));
            // Return existing token as fallback
            return {
                accessToken: account.oauth.accessToken,
                expiryDate: expiryDate,
                refreshToken: account.oauth.refreshToken,
                refreshed: false,
                error: err.message
            };
        }
    }

    return {
        accessToken: account.oauth.accessToken,
        expiryDate: expiryDate,
        refreshToken: account.oauth.refreshToken,
        refreshed: false
    };
}

/**
 * Fetch emails from Gmail using OAuth
 */
async function fetchEmailsFromGmail(account, pageToken = null) {
    console.log(`[Gmail] Fetching emails for ${account.email}...`);

    try {
        const tokenInfo = await refreshGmailToken(account);
        oauth2Client.setCredentials({ access_token: tokenInfo.accessToken });

        const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

        // List messages
        const listResponse = await gmail.users.messages.list({
            userId: 'me',
            maxResults: 20,
            pageToken: pageToken,
            q: 'in:inbox'
        });

        const messages = listResponse.data.messages || [];
        const nextPageToken = listResponse.data.nextPageToken;

        // Fetch full message details
        const emails = await Promise.all(messages.map(async (msg) => {
            try {
                const detail = await gmail.users.messages.get({
                    userId: 'me',
                    id: msg.id,
                    format: 'full'
                });

                const headers = detail.data.payload.headers;
                const getHeader = (name) => headers.find(h => h.name.toLowerCase() === name.toLowerCase())?.value || '';

                // Extract body
                let text = '';
                let html = '';

                const extractBody = (part) => {
                    if (part.mimeType === 'text/plain' && part.body.data) {
                        text = Buffer.from(part.body.data, 'base64').toString('utf-8');
                    } else if (part.mimeType === 'text/html' && part.body.data) {
                        html = Buffer.from(part.body.data, 'base64').toString('utf-8');
                    } else if (part.parts) {
                        part.parts.forEach(extractBody);
                    }
                };

                if (detail.data.payload.body.data) {
                    const content = Buffer.from(detail.data.payload.body.data, 'base64').toString('utf-8');
                    if (detail.data.payload.mimeType === 'text/html') {
                        html = content;
                    } else {
                        text = content;
                    }
                } else if (detail.data.payload.parts) {
                    detail.data.payload.parts.forEach(extractBody);
                }

                return {
                    id: `gmail_${account.email}_${msg.id}`,
                    messageId: msg.id,
                    threadId: msg.threadId,
                    accountName: account.name || account.email,
                    accountType: 'gmail',
                    subject: getHeader('Subject') || '(No Subject)',
                    from: getHeader('From') || 'Unknown',
                    to: getHeader('To') || '',
                    date: new Date(parseInt(detail.data.internalDate)),
                    text: text,
                    html: html,
                    isRead: !detail.data.labelIds.includes('UNREAD'),
                    snippet: detail.data.snippet || ''
                };
            } catch (err) {
                console.error(`[Gmail] Error fetching message ${msg.id}:`, err.message);
                return null;
            }
        }));

        return {
            emails: emails.filter(e => e !== null),
            nextPageToken,
            tokenInfo
        };

    } catch (err) {
        console.error(`[Gmail] Error fetching emails:`, err.message);
        return { emails: [], nextPageToken: null, tokenInfo: null };
    }
}

/**
 * POST /api/emails
 * Fetch emails from accounts stored in request body or fallback to .env
 */
app.post('/api/emails', async (req, res) => {
    try {
        const { accounts, offsets } = req.body;
        let allEmails = [];
        let pagination = {};

        if (accounts && accounts.length > 0) {
            console.log(`Fetching emails from ${accounts.length} account(s)...`);

            const emailPromises = accounts.map(async (account) => {
                if (account.provider === 'gmail-oauth') {
                    // Gmail OAuth account
                    const pageToken = offsets?.[account.email] || null;
                    const result = await fetchEmailsFromGmail(account, pageToken);

                    pagination[account.email] = {
                        nextPageToken: result.nextPageToken,
                        hasMore: !!result.nextPageToken
                    };

                    // Update token in Firestore if refreshed
                    if (result.tokenInfo?.refreshed) {
                        try {
                            const accountRef = await db.collection('emailAccounts')
                                .where('email', '==', account.email)
                                .where('companyId', '==', account.companyId)
                                .limit(1)
                                .get();

                            if (!accountRef.empty) {
                                await accountRef.docs[0].ref.update({
                                    'oauth.accessToken': result.tokenInfo.accessToken,
                                    'oauth.expiryDate': result.tokenInfo.expiryDate
                                });
                            }
                        } catch (updateErr) {
                            console.error('Error updating token in Firestore:', updateErr);
                        }
                    }

                    return result.emails;
                } else if (account.provider === 'microsoft-oauth') {
                    // Microsoft OAuth account
                    const skipToken = offsets?.[account.email] || null;
                    const result = await fetchEmailsFromMicrosoft(account, skipToken);

                    pagination[account.email] = {
                        nextPageToken: result.nextPageToken,
                        hasMore: !!result.nextPageToken
                    };

                    // Update token in Firestore if refreshed
                    if (result.tokenInfo?.refreshed) {
                        try {
                            const accountRef = await db.collection('emailAccounts')
                                .where('email', '==', account.email)
                                .where('companyId', '==', account.companyId)
                                .limit(1)
                                .get();

                            if (!accountRef.empty) {
                                await accountRef.docs[0].ref.update({
                                    'oauth.accessToken': result.tokenInfo.accessToken,
                                    'oauth.expiryDate': result.tokenInfo.expiryDate
                                });
                            }
                        } catch (updateErr) {
                            console.error('Error updating Microsoft token in Firestore:', updateErr);
                        }
                    }

                    return result.emails;
                } else if (account.imap) {
                    // IMAP account
                    const config = {
                        user: account.imap.user,
                        password: account.imap.password,
                        host: account.imap.host,
                        port: account.imap.port,
                        tls: account.imap.tls,
                        tlsOptions: { rejectUnauthorized: false },
                        authTimeout: 3000
                    };
                    return fetchEmailsFromAccount(config, account.name);
                }
                return [];
            });

            const results = await Promise.all(emailPromises);
            allEmails = results.flat();
        } else {
            // Fallback to .env configuration
            console.log('No accounts provided, checking .env fallback...');

            const hasValidEnv = fallbackConfig.imap.user &&
                fallbackConfig.imap.password &&
                fallbackConfig.imap.host &&
                fallbackConfig.imap.user !== 'undefined' &&
                fallbackConfig.imap.password !== 'undefined' &&
                fallbackConfig.imap.host !== 'undefined';

            if (!hasValidEnv) {
                console.log('No valid .env credentials found');
                return res.status(400).json({
                    error: 'No email accounts configured. Please add accounts in Email Accounts section.'
                });
            }

            console.log('Using .env fallback credentials');
            allEmails = await fetchEmailsFromAccount(fallbackConfig.imap, 'Default Account');
        }

        // Sort by date (newest first)
        allEmails.sort((a, b) => new Date(b.date) - new Date(a.date));

        res.json({
            emails: allEmails,
            pagination: pagination
        });
    } catch (err) {
        console.error('Error in /api/emails:', err);
        res.status(500).json({ error: 'Failed to fetch emails: ' + err.message });
    }
});

/**
 * POST /api/emails/:id/read
 * Mark email as read
 */
app.post('/api/emails/:id/read', async (req, res) => {
    const { id } = req.params;
    const { account, messageId } = req.body;

    try {
        if (account?.provider === 'gmail-oauth' && messageId) {
            const tokenInfo = await refreshGmailToken(account);
            oauth2Client.setCredentials({ access_token: tokenInfo.accessToken });

            const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

            await gmail.users.messages.modify({
                userId: 'me',
                id: messageId,
                requestBody: {
                    removeLabelIds: ['UNREAD']
                }
            });

            console.log(`[Gmail] Marked message ${messageId} as read`);
        }

        res.json({ success: true });
    } catch (err) {
        console.error('Error marking as read:', err);
        res.json({ success: false, error: err.message });
    }
});

/**
 * POST /api/test-connection
 * Test if an account can connect successfully
 */
app.post('/api/test-connection', async (req, res) => {
    try {
        const { account } = req.body;

        if (!account || !account.imap) {
            return res.status(400).json({ success: false, error: 'Missing account details' });
        }

        const config = {
            imap: {
                user: account.imap.user,
                password: account.imap.password,
                host: account.imap.host,
                port: account.imap.port,
                tls: account.imap.tls,
                tlsOptions: { rejectUnauthorized: false },
                authTimeout: 5000
            }
        };

        console.log(`Testing connection for ${account.imap.user} at ${account.imap.host}...`);

        const connection = await imaps.connect(config);
        await connection.openBox('INBOX');
        connection.end();

        console.log('Connection successful!');
        res.json({ success: true });

    } catch (err) {
        console.error('Test connection failed:', err);
        res.json({ success: false, error: err.message });
    }
});

/**
 * POST /api/calendar/events
 * Fetch calendar events from Google Calendar or Microsoft Calendar
 * FIXED: Better error handling and token management
 */
app.post('/api/calendar/events', async (req, res) => {
    const { account, timeMin, timeMax } = req.body;
    console.log('[Calendar] Request received:', {
        email: account?.email,
        provider: account?.provider,
        hasOAuth: !!(account?.oauth),
        hasAccessToken: !!(account?.oauth?.accessToken),
        hasRefreshToken: !!(account?.oauth?.refreshToken),
        timeMin,
        timeMax
    });

    if (!account || !account.oauth) {
        return res.status(400).json({ error: 'Missing account or OAuth credentials' });
    }

    if (!account.oauth.refreshToken && !account.oauth.accessToken) {
        return res.status(400).json({
            error: 'No valid OAuth tokens found. Please reconnect your account.'
        });
    }

    // Handle Microsoft OAuth accounts
    if (account.provider === 'microsoft-oauth') {
        try {
            const result = await fetchCalendarEventsFromMicrosoft(account, timeMin, timeMax);

            res.json({
                events: result.events,
                tokenRefreshed: result.tokenInfo?.refreshed ? {
                    accessToken: result.tokenInfo.accessToken,
                    expiryDate: result.tokenInfo.expiryDate
                } : null
            });
        } catch (err) {
            console.error('[Microsoft Calendar] Error:', err.message);
            res.status(500).json({ error: 'Failed to fetch Microsoft calendar events: ' + err.message });
        }
        return;
    }

    // Handle Google OAuth accounts (default)

    try {
        // Refresh the token
        const tokenInfo = await refreshGmailToken(account, true); // Force refresh for calendar

        if (tokenInfo.error) {
            console.error('[Calendar] Token refresh had error:', tokenInfo.error);
        }

        if (!tokenInfo.accessToken) {
            return res.status(401).json({
                error: 'Failed to obtain access token. Please reconnect your Gmail account.'
            });
        }

        console.log('[Calendar] Using token:', {
            hasAccessToken: !!tokenInfo.accessToken,
            tokenLength: tokenInfo.accessToken?.length,
            refreshed: tokenInfo.refreshed
        });

        // Create a fresh OAuth2 client for this request
        const calendarAuth = new google.auth.OAuth2(
            process.env.GOOGLE_CLIENT_ID,
            process.env.GOOGLE_CLIENT_SECRET,
            process.env.GOOGLE_REDIRECT_URI || `http://localhost:${port}/auth/google/callback`
        );

        calendarAuth.setCredentials({
            access_token: tokenInfo.accessToken,
            refresh_token: tokenInfo.refreshToken
        });

        const calendar = google.calendar({ version: 'v3', auth: calendarAuth });

        // Ensure datetime strings have timezone info (Google Calendar API requires it)
        const formatDateTime = (dt) => {
            if (!dt) return null;
            // If already has timezone info (Z or +/-), return as-is
            if (dt.endsWith('Z') || /[+-]\d{2}:\d{2}$/.test(dt)) {
                return dt;
            }
            // Otherwise, append 'Z' to treat as UTC
            return dt + 'Z';
        };

        const formattedTimeMin = formatDateTime(timeMin) || (new Date()).toISOString();
        const formattedTimeMax = formatDateTime(timeMax);

        console.log('[Calendar] Fetching events with:', {
            timeMin: formattedTimeMin,
            timeMax: formattedTimeMax
        });

        const response = await calendar.events.list({
            calendarId: 'primary',
            timeMin: formattedTimeMin,
            timeMax: formattedTimeMax,
            maxResults: 50,
            singleEvents: true,
            orderBy: 'startTime',
        });

        console.log('[Calendar] Success! Found', response.data.items?.length || 0, 'events');

        res.json({
            events: response.data.items,
            tokenRefreshed: tokenInfo.refreshed ? {
                accessToken: tokenInfo.accessToken,
                expiryDate: tokenInfo.expiryDate
            } : null
        });

    } catch (err) {
        console.error('[Calendar] API error:', err.message);

        // Log full error details
        if (err.response) {
            console.error('[Calendar] Response status:', err.response.status);
            console.error('[Calendar] Response data:', JSON.stringify(err.response.data, null, 2));
        }
        if (err.errors) {
            console.error('[Calendar] Errors array:', JSON.stringify(err.errors, null, 2));
        }

        // Provide more specific error messages
        let errorMessage = 'Failed to fetch calendar events: ' + err.message;

        if (err.response?.status === 401) {
            errorMessage = 'Authentication failed. Please reconnect your Gmail account.';
        } else if (err.response?.status === 403) {
            errorMessage = 'Calendar access denied. Please ensure calendar permissions were granted during OAuth.';
        } else if (err.response?.data?.error?.message) {
            errorMessage = err.response.data.error.message;
        }

        res.status(err.response?.status || 500).json({ error: errorMessage });
    }
});

// ============================================================================
// HEALTH CHECK & INFO
// ============================================================================

/**
 * GET /health
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

/**
 * GET /
 * Root endpoint - API info
 */
app.get('/', (req, res) => {
    res.json({
        name: 'SharedBox API',
        version: '2.1.0',
        status: 'running',
        endpoints: {
            health: '/health',
            googleOAuth: '/auth/google',
            microsoftOAuth: '/auth/microsoft',
            emails: '/api/emails',
            calendar: '/api/calendar/events'
        }
    });
});

// ============================================================================
// START SERVER
// ============================================================================

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Frontend URL: ${process.env.FRONTEND_URL || 'http://localhost:8080'}`);
    console.log('Email fetching mode: Multi-account (Firestore) + .env fallback');
});