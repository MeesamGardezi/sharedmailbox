const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'mailautomation-1'
    });
}
const db = admin.firestore();

async function listAccounts() {
    console.log('Listing email accounts...');
    const snapshot = await db.collection('emailAccounts').get();
    if (snapshot.empty) {
        console.log('No accounts found.');
        return;
    }

    snapshot.forEach(doc => {
        console.log(doc.id, '=>', doc.data());
    });
}

listAccounts().catch(console.error);
