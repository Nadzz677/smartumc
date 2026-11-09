import { createHmac, timingSafeEqual } from 'node:crypto';

export const QR_ROTATION_MS = 60_000;

export type AttendanceMode = 'physical' | 'online';
export type QrMode = 'static' | 'dynamic';
export type LocationEvidenceStatus =
  | 'captured'
  | 'not_opened'
  | 'permission_denied'
  | 'unavailable'
  | 'unreliable'
  | 'not_required';
export type AttendanceIndicator = 'green' | 'yellow' | 'red' | null;

export interface ScheduleEntry {
  scheduleType?: unknown;
  classDate?: unknown;
  scheduleDay?: unknown;
  startTime?: unknown;
  endTime?: unknown;
  venue?: unknown;
  groupId?: unknown;
  lecturerUid?: unknown;
}

export interface ClassOccurrence {
  classDate: string;
  scheduleDay: string;
  startTime: string;
  endTime: string;
  venue: string;
  groupId: string;
  scheduleIndex: number;
  occurrenceSource: 'lecturer_attested_schedule_template';
  semesterDateValidation: 'validated' | 'unavailable';
}

export interface LocationEvidence {
  status: LocationEvidenceStatus;
  source: 'client_reported' | 'not_applicable';
  latitude?: number;
  longitude?: number;
  accuracyMeters?: number;
  capturedAt?: number;
  reliability: 'unassessed' | 'reported_unreliable' | 'not_applicable';
}

export interface QrPayload {
  v: 1;
  sid: string;
  mode: QrMode;
  bucket?: number;
}

export class AttendanceDomainError extends Error {
  constructor(readonly code: 'invalid-argument' | 'failed-precondition' | 'permission-denied' | 'already-exists' | 'not-found', message: string) {
    super(message);
    this.name = 'AttendanceDomainError';
  }
}

function invalid(message: string): never {
  throw new AttendanceDomainError('invalid-argument', message);
}

function dateOnly(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return invalid('classDate must use YYYY-MM-DD.');
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    return invalid('classDate is not a valid calendar date.');
  }
  return value;
}

function isTime(value: unknown): value is string {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) return false;
  return true;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value && typeof value === 'object' && 'toDate' in value && typeof value.toDate === 'function') {
    return (value.toDate as () => Date)();
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isFinite(parsed.getTime()) ? parsed : null;
  }
  return null;
}

function scheduleWeekday(classDate: string): string {
  return ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][
    new Date(`${classDate}T00:00:00.000Z`).getUTCDay()
  ];
}

/**
 * The lecturer chooses a date for a weekly template. This validates a dated,
 * offering-bound occurrence snapshot, but is not proof of an official class
 * because the current synthetic semester has no official dates or schedules.
 */
export function validateOccurrence(
  input: unknown,
  offering: Record<string, unknown>,
  semester: Record<string, unknown>,
): ClassOccurrence {
  if (!input || typeof input !== 'object') return invalid('A dated class occurrence is required.');
  const request = input as Record<string, unknown>;
  const classDate = dateOnly(request.classDate);
  const schedule = offering.schedule;
  if (!Array.isArray(schedule) || !Number.isInteger(request.scheduleIndex)) {
    return invalid('Select a schedule template belonging to this offering.');
  }
  const scheduleIndex = request.scheduleIndex as number;
  const template = schedule[scheduleIndex] as ScheduleEntry | undefined;
  if (!template || template.scheduleType !== 'recurring_weekly') {
    return invalid('The selected schedule entry is not a recurring weekly template.');
  }
  if (!isTime(template.startTime) || !isTime(template.endTime) || template.endTime <= template.startTime) {
    return invalid('The offering has an invalid weekly schedule template.');
  }
  const scheduleDay = template.scheduleDay;
  if (typeof scheduleDay !== 'string' || scheduleDay !== scheduleWeekday(classDate)) {
    return invalid('The dated occurrence does not fall on the selected schedule day.');
  }
  if (
    !offering.groupId || template.groupId !== offering.groupId ||
    !offering.lecturerUid || template.lecturerUid !== offering.lecturerUid ||
    typeof template.venue !== 'string' || template.venue.trim() === ''
  ) {
    return invalid('The selected schedule template does not match its course offering.');
  }

  const startDate = dateValue(semester.startDate);
  const endDate = dateValue(semester.endDate);
  const occurrenceDate = new Date(`${classDate}T00:00:00.000Z`);
  if (startDate && occurrenceDate < new Date(Date.UTC(startDate.getUTCFullYear(), startDate.getUTCMonth(), startDate.getUTCDate()))) {
    return invalid('The class occurrence is before the semester.');
  }
  if (endDate && occurrenceDate > new Date(Date.UTC(endDate.getUTCFullYear(), endDate.getUTCMonth(), endDate.getUTCDate()))) {
    return invalid('The class occurrence is after the semester.');
  }

  return {
    classDate,
    scheduleDay,
    startTime: template.startTime,
    endTime: template.endTime,
    venue: template.venue.trim(),
    groupId: offering.groupId as string,
    scheduleIndex,
    occurrenceSource: 'lecturer_attested_schedule_template',
    semesterDateValidation: startDate && endDate ? 'validated' : 'unavailable',
  };
}

export function validateSessionMode(value: unknown): AttendanceMode {
  if (value === 'physical' || value === 'online') return value;
  return invalid('attendanceMode must be physical or online.');
}

export function validateQrMode(value: unknown): QrMode {
  if (value === 'static' || value === 'dynamic') return value;
  return invalid('qrMode must be static or dynamic.');
}

export function buildLocationEvidence(
  mode: AttendanceMode,
  value: unknown,
  nowMs: number,
): LocationEvidence {
  if (mode === 'online') {
    if (value != null) return invalid('Online attendance does not accept precise physical location.');
    return {
      status: 'not_required',
      source: 'not_applicable',
      reliability: 'not_applicable',
    };
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalid('Physical attendance requires a location evidence outcome.');
  }
  const input = value as Record<string, unknown>;
  const allowed = ['captured', 'not_opened', 'permission_denied', 'unavailable', 'unreliable'];
  if (typeof input.status !== 'string' || !allowed.includes(input.status)) {
    return invalid('Unknown physical location evidence status.');
  }

  const coordinateKeys = ['latitude', 'longitude', 'accuracyMeters', 'capturedAt'];
  const providedCount = coordinateKeys.filter((key) => input[key] !== undefined && input[key] !== null).length;
  if (input.status === 'captured' && providedCount !== coordinateKeys.length) {
    return invalid('Captured location evidence requires coordinates, accuracy, and timestamp.');
  }
  if (input.status !== 'captured' && input.status !== 'unreliable' && providedCount !== 0) {
    return invalid('Coordinates may only accompany captured or unreliable location evidence.');
  }
  if (providedCount !== 0 && providedCount !== coordinateKeys.length) {
    return invalid('Location coordinates, accuracy, and timestamp must be provided together.');
  }

  const evidence: LocationEvidence = {
    status: input.status as LocationEvidenceStatus,
    source: 'client_reported',
    reliability: input.status === 'unreliable' ? 'reported_unreliable' : 'unassessed',
  };
  if (providedCount === coordinateKeys.length) {
    const { latitude, longitude, accuracyMeters, capturedAt } = input;
    if (typeof latitude !== 'number' || !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
      return invalid('latitude must be a finite number between -90 and 90.');
    }
    if (typeof longitude !== 'number' || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      return invalid('longitude must be a finite number between -180 and 180.');
    }
    if (typeof accuracyMeters !== 'number' || !Number.isFinite(accuracyMeters) || accuracyMeters < 0) {
      return invalid('accuracyMeters must be a finite non-negative number.');
    }
    if (typeof capturedAt !== 'number' || !Number.isSafeInteger(capturedAt) || capturedAt < 0 || capturedAt > nowMs) {
      return invalid('capturedAt must be a plausible non-future Unix timestamp in milliseconds.');
    }
    evidence.latitude = latitude;
    evidence.longitude = longitude;
    evidence.accuracyMeters = accuracyMeters;
    evidence.capturedAt = capturedAt;
  }
  return evidence;
}

export function indicatorForSubmission(
  mode: AttendanceMode,
  evidence: LocationEvidence,
): AttendanceIndicator {
  if (mode === 'online' || evidence.status === 'not_required') return null;
  if (evidence.status === 'captured') return 'green';
  if (evidence.status === 'not_opened') return 'yellow';
  return null;
}

function signingKey(secret: string): Buffer {
  if (Buffer.byteLength(secret, 'utf8') < 32) {
    throw new AttendanceDomainError('failed-precondition', 'Attendance QR signing secret is not configured securely.');
  }
  return Buffer.from(secret, 'utf8');
}

function encodePayload(payload: QrPayload): string {
  return Buffer.from(JSON.stringify(payload)).toString('base64url');
}

export function signQrToken(payload: QrPayload, secret: string): string {
  const encoded = encodePayload(payload);
  const signature = createHmac('sha256', signingKey(secret)).update(encoded).digest('base64url');
  return `${encoded}.${signature}`;
}

export function createQrToken(
  sessionId: string,
  mode: QrMode,
  secret: string,
  nowMs: number,
): { token: string; validUntil: number | null } {
  const payload: QrPayload = mode === 'static'
    ? { v: 1, sid: sessionId, mode }
    : { v: 1, sid: sessionId, mode, bucket: Math.floor(nowMs / QR_ROTATION_MS) };
  return {
    token: signQrToken(payload, secret),
    validUntil: mode === 'static' ? null : (payload.bucket! + 1) * QR_ROTATION_MS,
  };
}

export function validateQrToken(
  token: unknown,
  sessionId: string,
  mode: QrMode,
  secret: string,
  nowMs: number,
): boolean {
  if (typeof token !== 'string' || token.length > 2048) return false;
  const parts = token.split('.');
  if (parts.length !== 2) return false;
  const [encoded, suppliedSignature] = parts;
  const expectedSignature = createHmac('sha256', signingKey(secret)).update(encoded).digest();
  let actualSignature: Buffer;
  try {
    actualSignature = Buffer.from(suppliedSignature, 'base64url');
  } catch {
    return false;
  }
  if (actualSignature.length !== expectedSignature.length || !timingSafeEqual(actualSignature, expectedSignature)) {
    return false;
  }
  let payload: unknown;
  try {
    payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
  } catch {
    return false;
  }
  if (!payload || typeof payload !== 'object') return false;
  const data = payload as Record<string, unknown>;
  if (data.v !== 1 || data.sid !== sessionId || data.mode !== mode) return false;
  if (mode === 'static') return data.bucket === undefined;
  return Number.isSafeInteger(data.bucket) && data.bucket === Math.floor(nowMs / QR_ROTATION_MS);
}
