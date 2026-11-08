const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { provisionSyntheticUser } = require('../lib/authentication');

function requireLocalEmulators() {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '';
  const isLocal = (host) => /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host);
  if (projectId !== 'demo-smartumc' || !isLocal(authHost) || !isLocal(firestoreHost)) {
    throw new Error('Refusing provisioning unless both local emulators and project demo-smartumc are active.');
  }
}

async function main() {
  requireLocalEmulators();
  const role = process.env.SMARTUMC_DEMO_ROLE;
  const email = process.env.SMARTUMC_DEMO_EMAIL;
  const matricNumber = process.env.SMARTUMC_DEMO_MATRIC;
  const password = process.env.SMARTUMC_DEMO_PASSWORD;
  const displayName = process.env.SMARTUMC_DEMO_DISPLAY_NAME;
  delete process.env.SMARTUMC_DEMO_PASSWORD;

  if (!role || !password || !displayName || (role === 'student' ? !matricNumber : !email)) {
    throw new Error('Set SMARTUMC_DEMO_ROLE, SMARTUMC_DEMO_PASSWORD, SMARTUMC_DEMO_DISPLAY_NAME, and role-specific identity variables.');
  }

  if (getApps().length === 0) initializeApp({ projectId: 'demo-smartumc' });
  const auth = getAuth();
  const firestore = getFirestore();
  const result = await provisionSyntheticUser(
    {
      auth: {
        getUserByEmail: async (address) => {
          try {
            return await auth.getUserByEmail(address);
          } catch (error) {
            if (error.code === 'auth/user-not-found') return null;
            throw error;
          }
        },
        createUser: (input) => auth.createUser(input),
        setCustomUserClaims: (uid, claims) => auth.setCustomUserClaims(uid, claims),
        deleteUser: (uid) => auth.deleteUser(uid),
      },
      profiles: {
        get: async (uid) => {
          const snapshot = await firestore.collection('users').doc(uid).get();
          return snapshot.exists ? snapshot.data() ?? null : null;
        },
        set: (uid, profile) =>
          firestore.collection('users').doc(uid).set(profile, { merge: true }),
        delete: async (uid) => {
          await firestore.collection('users').doc(uid).delete();
        },
      },
      serverTimestamp: () => FieldValue.serverTimestamp(),
    },
    { role, email, matricNumber, password, displayName },
  );

  console.log(`Provisioned synthetic ${result.role} account in emulators. UID: ${result.uid}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
