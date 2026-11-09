const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { provisionSyntheticUser, studentEmailAlias } = require('../lib/authentication');
const { buildSyntheticAcademicDataset, seedSyntheticAcademicDataset } = require('../lib/academics');

function requireLocalEmulators() {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '';
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '';
  const isLocal = (host) => /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host);
  if (projectId !== 'demo-smartumc' || !isLocal(authHost) || !isLocal(firestoreHost)) {
    throw new Error('Refusing academic seeding unless Auth and Firestore emulators use demo-smartumc and loopback endpoints.');
  }
}

async function main() {
  requireLocalEmulators();
  const password = process.env.SMARTUMC_SEED_PASSWORD;
  delete process.env.SMARTUMC_SEED_PASSWORD;
  if (!password || password.length < 6) throw new Error('Set SMARTUMC_SEED_PASSWORD to a synthetic emulator-only password.');

  const identities = [
    { role: 'lecturer', email: 'lecturer.demo@staff.smartumc.invalid', displayName: 'Synthetic Lecturer' },
    { role: 'student', matricNumber: 'DIT2026001', displayName: 'Synthetic Student G01', groupId: 'G01' },
    { role: 'student', matricNumber: 'DIT2026002', displayName: 'Synthetic Student G02', groupId: 'G02' },
  ];
  if (getApps().length === 0) initializeApp({ projectId: 'demo-smartumc' });
  const auth = getAuth();
  const firestore = getFirestore();
  const provisionDependencies = {
    auth: {
      getUserByEmail: async (email) => {
        try { return await auth.getUserByEmail(email); }
        catch (error) { if (error.code === 'auth/user-not-found') return null; throw error; }
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
      set: (uid, profile) => firestore.collection('users').doc(uid).set(profile, { merge: true }),
      delete: async (uid) => { await firestore.collection('users').doc(uid).delete(); },
    },
    serverTimestamp: () => FieldValue.serverTimestamp(),
  };

  const provisioned = [];
  for (const identity of identities) {
    const identityEmail = identity.role === 'student'
      ? studentEmailAlias(identity.matricNumber)
      : identity.email;
    let priorUser = null;
    try { priorUser = await auth.getUserByEmail(identityEmail); }
    catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
    if (priorUser) {
      const priorProfile = (await firestore.collection('users').doc(priorUser.uid).get()).data() ?? {};
      if (priorProfile.displayName !== undefined && priorProfile.displayName !== identity.displayName) {
        throw new Error(`Refusing to overwrite conflicting synthetic profile for ${identityEmail}.`);
      }
      const expectedAcademicFields = {
        dataClassification: 'synthetic_demo',
        ...(identity.role === 'student' ? {
          programme: 'DIT',
          academicSession: '2026/2027',
          demonstrationGroupId: identity.groupId,
        } : {}),
      };
      for (const [key, value] of Object.entries(expectedAcademicFields)) {
        if (priorProfile[key] !== undefined && priorProfile[key] !== value) {
          throw new Error(`Refusing to overwrite conflicting synthetic academic profile field ${key} for ${priorUser.uid}.`);
        }
      }
    }
    const user = await provisionSyntheticUser(provisionDependencies, { ...identity, password });
    const academicProfile = {
      dataClassification: 'synthetic_demo',
      ...(identity.role === 'student' ? {
        programme: 'DIT',
        academicSession: '2026/2027',
        demonstrationGroupId: identity.groupId,
      } : {}),
    };
    const profileRef = firestore.collection('users').doc(user.uid);
    const existing = (await profileRef.get()).data() ?? {};
    for (const [key, value] of Object.entries(academicProfile)) {
      if (existing[key] !== undefined && existing[key] !== value) {
        throw new Error(`Refusing conflicting synthetic academic profile field ${key} for ${user.uid}.`);
      }
    }
    await profileRef.set(academicProfile, { merge: true });
    provisioned.push({ ...identity, uid: user.uid });
  }

  const students = provisioned.filter((user) => user.role === 'student');
  const lecturer = provisioned.find((user) => user.role === 'lecturer');
  const dataset = buildSyntheticAcademicDataset({
    lecturerUid: lecturer.uid,
    studentUids: [students[0].uid, students[1].uid],
  });
  const result = await seedSyntheticAcademicDataset({
    get: async (collection, id) => {
      const snapshot = await firestore.collection(collection).doc(id).get();
      return snapshot.exists ? snapshot.data() ?? null : null;
    },
    create: async (collection, id, data) => {
      await firestore.collection(collection).doc(id).create(data);
    },
  }, dataset);
  console.log(`Academic emulator seed complete: ${result.created} created, ${result.alreadyPresent} already present.`);
  console.log('Synthetic identities: DIT2026001 (G01), DIT2026002 (G02), lecturer.demo@staff.smartumc.invalid.');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
