const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildSyntheticAcademicDataset,
  enrollmentDocumentId,
  seedSyntheticAcademicDataset,
} = require('../lib/academics');

test('builds a stable three-semester synthetic dataset with deterministic enrollments', async () => {
  const documents = buildSyntheticAcademicDataset({ lecturerUid: 'lecturer-1', studentUids: ['student-1', 'student-2'] });
  assert.equal(documents.filter((item) => item.collection === 'semesters').length, 3);
  assert.equal(documents.filter((item) => item.collection === 'courses').length, 5);
  assert.equal(documents.filter((item) => item.collection === 'courseOfferings').length, 12);
  assert.equal(documents.filter((item) => item.collection === 'enrollments').length, 12);
  assert.equal(new Set(documents.filter((item) => item.collection === 'enrollments').map((item) => item.id)).size, 12);
  assert.equal(enrollmentDocumentId('offer', 'student'), 'offer_student');
  assert.throws(() => enrollmentDocumentId('offer/path', 'student'));
  assert.equal(documents.find((item) => item.id === 'DIT-2026-2027-S1').data.startDate, null);
  assert.equal(documents.find((item) => item.id === 'computer-forensic').data.courseCode, null);
  assert.ok(documents.every((item) => item.data.dataClassification === 'synthetic_demo'));

  const byCollectionAndId = new Map(documents.map((item) => [`${item.collection}/${item.id}`, item]));
  const offerings = documents.filter((item) => item.collection === 'courseOfferings');
  for (const offering of offerings) {
    assert.ok(byCollectionAndId.has(`courses/${offering.data.courseId}`));
    assert.ok(byCollectionAndId.has(`semesters/${offering.data.semesterId}`));
    assert.equal(offering.data.lecturerUid, 'lecturer-1');
    for (const entry of offering.data.schedule) {
      assert.equal(entry.groupId, offering.data.groupId);
      assert.equal(entry.lecturerUid, offering.data.lecturerUid);
    }
  }
  for (const enrollment of documents.filter((item) => item.collection === 'enrollments')) {
    const offering = byCollectionAndId.get(`courseOfferings/${enrollment.data.courseOfferingId}`);
    assert.ok(offering);
    assert.ok(['student-1', 'student-2'].includes(enrollment.data.studentUid));
    assert.equal(enrollment.data.courseId, offering.data.courseId);
    assert.equal(enrollment.data.semesterId, offering.data.semesterId);
    assert.equal(enrollment.data.groupId, offering.data.groupId);
  }
});

test('create-only seeding is idempotent and refuses conflicting existing data', async () => {
  const documents = [{ collection: 'courses', id: 'example', data: { name: 'Synthetic' } }];
  const records = new Map();
  const store = {
    get: async (collection, id) => records.get(`${collection}/${id}`) ?? null,
    create: async (collection, id, data) => {
      const key = `${collection}/${id}`;
      if (records.has(key)) throw new Error('already exists');
      records.set(key, structuredClone(data));
    },
  };
  assert.deepEqual(await seedSyntheticAcademicDataset(store, documents), { created: 1, alreadyPresent: 0 });
  assert.deepEqual(await seedSyntheticAcademicDataset(store, documents), { created: 0, alreadyPresent: 1 });
  records.set('courses/example', { name: 'Conflicting' });
  await assert.rejects(seedSyntheticAcademicDataset(store, documents), /Refusing to overwrite conflicting/);
});
