/**
 * WhatsApp Integration Module
 * Handles WhatsApp Web session management and message logging
 */

const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');

// Store active clients and QR codes
const clients = new Map();
const qrCodes = new Map();

/**
 * Initialize WhatsApp module with required dependencies
 * @param {Object} io - Socket.io instance
 * @param {Object} db - Firestore database instance
 * @param {Object} storage - Firebase Storage instance
 */
function initWhatsApp(io, db, storage) {

    /**
     * Start a WhatsApp session for a user
     */
    async function startSession(userId) {
        if (clients.has(userId)) {
            console.log(`[WhatsApp] Session already exists for ${userId}`);
            return clients.get(userId);
        }

        console.log(`[WhatsApp] Starting session for ${userId}...`);

        const client = new Client({
            authStrategy: new LocalAuth({ clientId: userId }),
            puppeteer: {
                headless: true,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--disable-gpu'
                ]
            }
        });

        client.on('qr', async (qr) => {
            console.log(`[WhatsApp] QR Code generated for ${userId}`);
            qrcode.generate(qr, { small: true });

            try {
                const qrDataUrl = await QRCode.toDataURL(qr, { width: 256 });
                qrCodes.set(userId, qrDataUrl);
                io.to(`user-${userId}`).emit('qr', qrDataUrl);
            } catch (err) {
                console.error('[WhatsApp] Error generating QR image:', err);
            }
        });

        client.on('authenticated', () => {
            console.log(`[WhatsApp] Authenticated for user: ${userId}`);
        });

        client.on('ready', async () => {
            console.log(`[WhatsApp] Client ready for ${userId}`);
            qrCodes.delete(userId);

            try {
                const info = client.info;
                const phone = info.wid.user;
                const name = info.pushname || 'WhatsApp User';

                await db.collection('whatsappAccounts').doc(userId).set({
                    status: 'connected',
                    phone: phone,
                    name: name,
                    connectedAt: new Date(),
                    updatedAt: new Date()
                }, { merge: true });

                io.to(`user-${userId}`).emit('ready', { phone, name });
                console.log(`[WhatsApp] Account linked for ${userId}: ${name} (${phone})`);
            } catch (err) {
                console.error(`[WhatsApp] Error updating connection status:`, err);
            }
        });

        client.on('message', async (message) => {
            await handleMessage(userId, message, client, db, storage);
        });

        client.on('disconnected', async (reason) => {
            console.log(`[WhatsApp] Disconnected for ${userId}:`, reason);
            clients.delete(userId);
            qrCodes.delete(userId);

            try {
                await db.collection('whatsappAccounts').doc(userId).update({
                    status: 'disconnected',
                    disconnectedAt: new Date(),
                    disconnectReason: reason
                });
            } catch (err) {
                console.error(`[WhatsApp] Error updating disconnect status:`, err);
            }

            io.to(`user-${userId}`).emit('disconnected', reason);
        });

        try {
            await client.initialize();
            clients.set(userId, client);
        } catch (err) {
            console.error(`[WhatsApp] Error initializing client for ${userId}:`, err);
            throw err;
        }

        return client;
    }

    /**
     * Stop a WhatsApp session
     */
    async function stopSession(userId) {
        const client = clients.get(userId);
        if (client) {
            await client.destroy();
            clients.delete(userId);
            qrCodes.delete(userId);
            console.log(`[WhatsApp] Session stopped for ${userId}`);
        }
    }

    /**
     * Get session status
     */
    async function getSessionStatus(userId) {
        const client = clients.get(userId);
        if (!client) {
            return { status: 'not_started' };
        }

        try {
            const info = client.info;
            if (info) {
                return {
                    status: 'connected',
                    phone: info.wid.user,
                    name: info.pushname || 'WhatsApp User'
                };
            }
        } catch (err) {
            // Client exists but not ready
        }

        return { status: 'connecting' };
    }

    /**
     * Get QR code for a session
     */
    function getQRCode(userId) {
        return qrCodes.get(userId) || null;
    }

    /**
     * Get available groups for a user
     */
    async function getGroups(userId) {
        const client = clients.get(userId);
        if (!client) {
            return [];
        }

        try {
            const chats = await client.getChats();
            const groups = chats.filter(chat => chat.isGroup);

            return groups.map(group => ({
                id: group.id._serialized,
                name: group.name,
                participantCount: group.participants?.length || 0
            }));
        } catch (err) {
            console.error(`[WhatsApp] Error getting groups:`, err);
            return [];
        }
    }

    /**
     * Handle incoming message
     */
    async function handleMessage(userId, message, client, db, storage) {
        try {
            const isGroup = message.from.includes('@g.us');
            if (!isGroup) return;

            const groupId = message.from;

            const monitoredSnapshot = await db.collection('monitoredGroups')
                .where('userId', '==', userId)
                .where('groupId', '==', groupId)
                .get();

            if (monitoredSnapshot.empty) return;

            console.log(`[WhatsApp] Processing message from ${groupId} for ${userId}`);

            let senderName = 'Unknown';
            let senderPhone = '';
            let groupName = 'Unknown Group';

            try {
                const chat = await message.getChat();
                groupName = chat.name || 'Unknown Group';

                const authorId = message.author || message.from;
                senderPhone = authorId ? authorId.split('@')[0] : '';

                try {
                    const contact = await message.getContact();
                    if (contact) {
                        senderName = contact.pushname || contact.name || senderPhone || 'Unknown';
                    }
                } catch (contactErr) {
                    if (message._data && message._data.notifyName) {
                        senderName = message._data.notifyName;
                    } else {
                        senderName = senderPhone || 'Unknown';
                    }
                }
            } catch (infoErr) {
                console.error(`[WhatsApp] Error getting message info:`, infoErr);
                const authorId = message.author || message.from;
                senderPhone = authorId ? authorId.split('@')[0] : '';
                senderName = senderPhone || 'Unknown';
            }

            const messageData = {
                groupId: groupId,
                userId: userId,
                groupName: groupName,
                sender: message.author || message.from,
                senderName: senderName,
                senderPhone: senderPhone,
                content: message.body || '',
                timestamp: new Date(message.timestamp * 1000),
                type: message.type,
                hasMedia: message.hasMedia
            };

            if (message.hasMedia) {
                try {
                    const media = await message.downloadMedia();
                    if (media) {
                        const extension = getExtensionFromMimetype(media.mimetype);
                        const filename = `${Date.now()}_media.${extension}`;
                        const filePath = `media/${userId}/${filename}`;
                        const file = storage.bucket().file(filePath);

                        await file.save(Buffer.from(media.data, 'base64'), {
                            metadata: { contentType: media.mimetype }
                        });

                        await file.makePublic();

                        const bucket = storage.bucket();
                        messageData.mediaUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;
                        messageData.mediaType = media.mimetype;
                        console.log(`[WhatsApp] Media saved: ${filePath}`);
                    }
                } catch (mediaErr) {
                    console.error(`[WhatsApp] Error handling media:`, mediaErr);
                    messageData.mediaError = true;
                }
            }

            await db.collection('messages').add(messageData);
            console.log(`[WhatsApp] Message saved from ${senderName} in ${groupName}`);

        } catch (err) {
            console.error(`[WhatsApp] Error handling message:`, err);
        }
    }

    return {
        startSession,
        stopSession,
        getSessionStatus,
        getQRCode,
        getGroups
    };
}

/**
 * Get file extension from mimetype
 */
function getExtensionFromMimetype(mimetype) {
    const mimeMap = {
        'image/jpeg': 'jpg',
        'image/jpg': 'jpg',
        'image/png': 'png',
        'image/gif': 'gif',
        'image/webp': 'webp',
        'video/mp4': 'mp4',
        'video/3gpp': '3gp',
        'audio/ogg': 'ogg',
        'audio/mpeg': 'mp3',
        'audio/ogg; codecs=opus': 'ogg'
    };
    return mimeMap[mimetype] || 'media';
}

module.exports = { initWhatsApp };
