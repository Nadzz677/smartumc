const test = require('node:test');
const assert = require('node:assert/strict');
const {
  QR_ROTATION_MS,
  AttendanceDomainError,
  buildLocationEvidence,
  createQrToken,
  indicatorForSubmission,
  validateOccurrence,
  validateQrToken,
} = require('../lib/attendance/domain');

const secret = 'synthetic-emulator-attendance-secret-32-bytes';
const offering = {
  semesterId: 'semester-1',
  lecturerUid: 'lecturer-1',
  groupId: 'G01',
  schedule: [{
    scheduleType: 'recurring_weekly',
    scheduleDay: 'Tuesday',
    startTime: '09:00',
    endTime: '10:00',
    venue: 'BK A1',
    lecturerUid: 'lecturer-1',
    groupId: 'G01',
  }],
};

test('validates a dated occurrence against the offering template without inventing semester bounds', () => {
  const occurrence = validateOccurrence(
    { classDate: '2026-11-10', scheduleIndex: 0 },
    offering,
    { startDate: null, endDate: null },
  );
  assert.equal(occurrence.scheduleDay, 'Tuesday');
  assert.equal(occurrence.startTime, '09:00');
  assert.equal(occurrence.venue, 'BK A1');
  assert.equal(occurrence.semesterDateValidation, 'unavailable');
});

test('rejects invalid dates, weekday mismatches, invalid template indexes, and dates outside known semester bounds', () => {
  assert.throws(() => validateOccurrence({ classDate: '2026-02-30', scheduleIndex: 0 }, offering, {}), AttendanceDomainError);
  assert.throws(() => validateOccurrence({ classDate: '2026-11-11', scheduleIndex: 0 }, offering, {}), /schedule day/);
  assert.throws(() => validateOccurrence({ classDate: '2026-11-10', scheduleIndex: 1 }, offering, {}), /schedule entry/);
  assert.throws(() => validateOccurrence({ classDate: '2026-11-10', scheduleIndex: 0 }, offering, {
    startDate: new Date('2026-11-11T00:00:00Z'), endDate: new Date('2026-12-31T00:00:00Z'),
  }), /before the semester/);
});

test('static QR is session-bound, reusable, and remains valid until session lifecycle rejects it', () => {
  const issued = createQrToken('session-A', 'static', secret, 1_000);
  assert.equal(issued.validUntil, null);
  assert.equal(validateQrToken(issued.token, 'session-A', 'static', secret, 99_000_000), true);
  assert.equal(validateQrToken(issued.token, 'session-B', 'static', secret, 1_000), false);
  assert.equal(validateQrToken(issued.token, 'session-A', 'dynamic', secret, 1_000), false);
  assert.equal(validateQrToken(`${issued.token}x`, 'session-A', 'static', secret, 1_000), false);
});

test('dynamic QR rotates at exactly 60 seconds and rejects altered or expired tokens', () => {
  const now = 1_800_000;
  const issued = createQrToken('session-A', 'dynamic', secret, now);
  assert.equal(issued.validUntil, (Math.floor(now / QR_ROTATION_MS) + 1) * QR_ROTATION_MS);
  assert.equal(validateQrToken(issued.token, 'session-A', 'dynamic', secret, now + QR_ROTATION_MS - 1), true);
  assert.equal(validateQrToken(issued.token, 'session-A', 'dynamic', secret, now + QR_ROTATION_MS), false);
  const [payload, signature] = issued.token.split('.');
  const changed = `${payload.slice(0, -1)}${payload.endsWith('A') ? 'B' : 'A'}.${signature}`;
  assert.equal(validateQrToken(changed, 'session-A', 'dynamic', secret, now), false);
  assert.equal(validateQrToken(issued.token, 'session-A', 'dynamic', 'different-signing-secret-which-is-32-bytes', now), false);
});

test('physical location outcomes remain separate and validate supplied measurements without thresholds', () => {
  const captured = buildLocationEvidence('physical', {
    status: 'captured', latitude: 90, longitude: -180,
    accuracyMeters: 99_999, capturedAt: 1_000,
  }, 2_000);
  assert.equal(captured.status, 'captured');
  assert.equal(captured.accuracyMeters, 99_999);
  assert.equal(indicatorForSubmission('physical', captured), 'green');

  const unreliable = buildLocationEvidence('physical', {
    status: 'unreliable', latitude: 1, longitude: 2,
    accuracyMeters: 10_000, capturedAt: 1_000,
  }, 2_000);
  assert.equal(unreliable.reliability, 'reported_unreliable');
  assert.equal(indicatorForSubmission('physical', unreliable), null);
  assert.equal(indicatorForSubmission('physical', buildLocationEvidence('physical', { status: 'not_opened' }, 2_000)), 'yellow');
  for (const status of ['permission_denied', 'unavailable']) {
    assert.equal(buildLocationEvidence('physical', { status }, 2_000).status, status);
  }
});

test('location validation rejects malformed coordinates and implausible future timestamps', () => {
  const base = { status: 'captured', latitude: 1, longitude: 2, accuracyMeters: 1, capturedAt: 2_001 };
  assert.throws(() => buildLocationEvidence('physical', base, 2_000), /timestamp/);
  assert.throws(() => buildLocationEvidence('physical', { ...base, capturedAt: 1, latitude: 91 }, 2_000), /latitude/);
  assert.throws(() => buildLocationEvidence('physical', { ...base, capturedAt: 1, longitude: 181 }, 2_000), /longitude/);
  assert.throws(() => buildLocationEvidence('physical', { ...base, capturedAt: 1, accuracyMeters: -1 }, 2_000), /accuracyMeters/);
  assert.throws(() => buildLocationEvidence('physical', { status: 'captured', latitude: 1 }, 2_000), /requires coordinates/);
});

test('online attendance omits physical location and never maps missing GPS to a color', () => {
  const evidence = buildLocationEvidence('online', undefined, 2_000);
  assert.equal(evidence.status, 'not_required');
  assert.equal(evidence.source, 'not_applicable');
  assert.equal(indicatorForSubmission('online', evidence), null);
  assert.throws(() => buildLocationEvidence('online', { status: 'captured' }, 2_000), /does not accept/);
});
