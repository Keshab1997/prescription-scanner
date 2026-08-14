// Seed Firestore with the first Gemini key + admin contact.
// Requires Application Default Credentials:
//   export GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json
//   npm i firebase-admin
//   node scripts/seed_firestore.js
const admin = require('firebase-admin');
const { Timestamp } = require('firebase-admin/firestore');

admin.initializeApp({ projectId: 'prescription-scanner-admin' });
const db = admin.firestore();

const ADMIN_EMAIL = 'Keshabsarkar2018@gmail.com';

async function main() {
  const now = Timestamp.now();
  await db.collection('admin_api_keys').add({
    name: 'Default Key',
    key: process.env.GEMINI_API_KEY ?? 'REPLACE_WITH_GEMINI_KEY',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-1.5-flash',
    provider: 'google',
    isActive: true,
    priority: 1,
    usageCount: 0,
    errorCount: 0,
    addedBy: ADMIN_EMAIL,
    createdAt: now,
    updatedAt: now,
  });
  await db.collection('admin_contacts').doc('primary').set({
    email: ADMIN_EMAIL,
    phone: '9382284190',
    updatedAt: now,
  });
  console.log('Seeded admin_api_keys + admin_contacts.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
