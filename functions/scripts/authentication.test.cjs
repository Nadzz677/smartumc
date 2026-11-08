const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeMatricNumber,
  studentEmailAlias,
  provisionSyntheticUser,
} = require('../lib/authentication');
const { parseUserRole, requireUserRole } = require('../lib/authorization');

test('normalizes matric input and creates the internal email alias', () => {
  assert.equal(normalizeMatricNumber(' DIT2026001 '), 'dit2026001');
  assert.equal(studentEmailAlias('DIT2026001'), 'dit2026001@students.smartumc.invalid');
});

test('rejects malformed matric input and unapproved role claims', () => {
  for (const matric of ['', 'dit 2026001', 'student@example.com', '!invalid']) {
    assert.throws(() => normalizeMatricNumber(matric));
  }
  assert.equal(parseUserRole(undefined), null);
  assert.equal(parseUserRole('admin'), null);
  assert.throws(() => requireUserRole('superadmin'));
});

function fakeDependencies(overrides = {}) {
  const users = new Map();
  const profiles = new Map();
  const calls = [];
  let nextUid = 1;
  const deps = {
    auth: {
      async getUserByEmail(email) {
        return [...users.values()].find((user) => user.email === email) ?? null;
      },
      async createUser(input) {
        const user = { ...input, uid: `synthetic-${nextUid++}`, customClaims: {} };
        users.set(user.uid, user);
        calls.push('createUser');
        return user;
      },
      async setCustomUserClaims(uid, claims) {
        calls.push('setCustomUserClaims');
        const user = users.get(uid);
        if (user) user.customClaims = claims;
        if (overrides.claimsError && claims.role) throw new Error('claims failure');
      },
      async deleteUser(uid) {
        calls.push('deleteUser');
        users.delete(uid);
      },
    },
    profiles: {
      async get(uid) { return profiles.get(uid) ?? null; },
      async set(uid, profile) {
        calls.push('profileSet');
        if (overrides.profileError) throw new Error('profile failure');
        profiles.set(uid, { ...(profiles.get(uid) ?? {}), ...profile });
      },
      async delete(uid) {
        calls.push('profileDelete');
        profiles.delete(uid);
      },
    },
    serverTimestamp: () => 'server-time',
    users,
    storedProfiles: profiles,
    calls,
    overrides,
  };
  return deps;
}

const studentRequest = {
  role: 'student', matricNumber: 'DIT2026001', password: 'synthetic-password',
  displayName: 'Synthetic Student',
};

test('provisions trusted claims and profile and safely reconciles a retry', async () => {
  const deps = fakeDependencies();
  const first = await provisionSyntheticUser(deps, studentRequest);
  assert.equal(first.role, 'student');
  assert.equal(first.reconciled, false);
  assert.equal(deps.users.get(first.uid).customClaims.role, 'student');
  assert.equal(deps.storedProfiles.get(first.uid).status, 'active');
  const retry = await provisionSyntheticUser(deps, studentRequest);
  assert.equal(retry.uid, first.uid);
  assert.equal(retry.reconciled, true);
  assert.equal(deps.calls.filter((call) => call === 'createUser').length, 1);
});

test('refuses to reconcile a profile bound to a different email identity', async () => {
  const deps = fakeDependencies();
  const provisioned = await provisionSyntheticUser(deps, studentRequest);
  deps.storedProfiles.get(provisioned.uid).email = 'other@students.smartumc.invalid';
  await assert.rejects(() => provisionSyntheticUser(deps, studentRequest), /provisioning failed/i);
  assert.equal(deps.users.get(provisioned.uid).customClaims.role, 'student');
});

test('rejects non-synthetic staff identities before touching Firebase', async () => {
  const deps = fakeDependencies();
  await assert.rejects(() => provisionSyntheticUser(deps, {
    role: 'lecturer', email: 'lecturer@university.edu', password: 'synthetic-password',
    displayName: 'Synthetic Lecturer',
  }));
  assert.equal(deps.calls.length, 0);
});

test('supports trusted Super Admin provisioning only with a synthetic identity', async () => {
  const deps = fakeDependencies();
  const provisioned = await provisionSyntheticUser(deps, {
    role: 'super_admin',
    email: 'admin@smartumc.invalid',
    password: 'synthetic-password',
    displayName: 'Synthetic Super Admin',
  });
  assert.equal(provisioned.role, 'super_admin');
  assert.equal(deps.users.get(provisioned.uid).customClaims.role, 'super_admin');
});

test('rolls back a newly-created Auth account when profile creation fails', async () => {
  const deps = fakeDependencies({ profileError: true });
  await assert.rejects(() => provisionSyntheticUser(deps, studentRequest), /provisioning failed/i);
  assert.equal(deps.users.size, 0);
  assert.equal(deps.storedProfiles.size, 0);
  assert.ok(deps.calls.includes('deleteUser'));
});

test('restores prior claims after a failed reconciliation and retries safely', async () => {
  const deps = fakeDependencies();
  const initial = await provisionSyntheticUser(deps, studentRequest);
  const profileBefore = { ...deps.storedProfiles.get(initial.uid) };
  deps.overrides.profileError = true;

  await assert.rejects(() => provisionSyntheticUser(deps, {
    ...studentRequest,
    displayName: 'Updated Synthetic Student',
  }), /provisioning failed/i);
  assert.equal(deps.users.get(initial.uid).customClaims.role, 'student');
  assert.deepEqual(deps.storedProfiles.get(initial.uid), profileBefore);

  deps.overrides.profileError = false;
  const retry = await provisionSyntheticUser(deps, {
    ...studentRequest,
    displayName: 'Updated Synthetic Student',
  });
  assert.equal(retry.uid, initial.uid);
  assert.equal(deps.storedProfiles.get(initial.uid).displayName, 'Updated Synthetic Student');
});
