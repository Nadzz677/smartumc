/** Synthetic DIT demonstration dataset builder and conflict-safe seeder. */

export const ACADEMIC_SESSION = '2026/2027';
export const SYNTHETIC_MARKER = 'synthetic_demo';

export const SEMESTER_IDS = [
  'DIT-2026-2027-S1',
  'DIT-2026-2027-S2',
  'DIT-2026-2027-S3',
] as const;

export interface AcademicDocument {
  [field: string]: unknown;
}

export interface DatasetDocument {
  collection: 'semesters' | 'courses' | 'courseOfferings' | 'enrollments';
  id: string;
  data: AcademicDocument;
}

export interface AcademicSeedStore {
  get(collection: string, id: string): Promise<AcademicDocument | null>;
  create(collection: string, id: string, data: AcademicDocument): Promise<void>;
}

const courses = [
  { id: 'BBA1152', courseCode: 'BBA1152', courseName: 'Advanced English II', creditHours: 2, confirmationStatus: 'confirmed_reference' },
  { id: 'KOM4263', courseCode: 'KOM4263', courseName: 'Pengaturcaraan Web', creditHours: 3, confirmationStatus: 'confirmed_reference' },
  { id: 'computer-forensic', courseCode: null, courseName: 'Computer Forensic', creditHours: null, confirmationStatus: 'pending_confirmation' },
  { id: 'sulam', courseCode: null, courseName: 'SULAM', creditHours: null, confirmationStatus: 'pending_confirmation' },
  { id: 'projek-1', courseCode: null, courseName: 'Projek 1', creditHours: null, confirmationStatus: 'pending_confirmation' },
] as const;

function scheduleEntry(course: typeof courses[number], groupId: string, lecturerUid: string, index: number) {
  const venues = ['BK A1', 'Makmal Komputer 1', 'Makmal Komputer 2', 'Makmal Komputer 3'];
  const days = ['Tuesday', 'Wednesday'] as const;
  const startTimes = groupId === 'G01' ? ['09:00', '11:00'] : ['13:00', '15:00'];
  const startTime = startTimes[index];
  const [hour, minute] = startTime.split(':').map(Number);
  const endTime = `${String(hour + 1).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  return {
    scheduleType: 'recurring_weekly',
    classDate: null,
    scheduleDay: days[index],
    courseCode: course.courseCode,
    courseName: course.courseName,
    groupId,
    startTime,
    endTime,
    venue: venues[(index + (groupId === 'G02' ? 2 : 0)) % venues.length],
    lecturerUid,
    attendanceStatus: null,
    notes: 'Synthetic timetable fixture; not an official DIT schedule.',
  };
}

export function enrollmentDocumentId(offeringId: string, studentUid: string): string {
  if (!offeringId || !studentUid || offeringId.includes('/') || studentUid.includes('/')) {
    throw new Error('Valid offering and student identifiers are required.');
  }
  return `${offeringId}_${studentUid}`;
}

/** Creates a stable, explicitly synthetic test dataset with no official dates. */
export function buildSyntheticAcademicDataset(input: {
  lecturerUid: string;
  studentUids: readonly [string, string];
}): DatasetDocument[] {
  if (!input.lecturerUid || input.studentUids.some((uid) => !uid) || new Set(input.studentUids).size !== 2) {
    throw new Error('One lecturer UID and two distinct student UIDs are required.');
  }
  const documents: DatasetDocument[] = [];
  SEMESTER_IDS.forEach((id, index) => documents.push({
    collection: 'semesters', id,
    data: {
      academicSession: ACADEMIC_SESSION,
      semesterNumber: index + 1,
      displayName: `DIT Representative Semester ${index + 1} (2026/2027)`,
      startDate: null,
      endDate: null,
      status: 'pending_official_dates',
      dataClassification: SYNTHETIC_MARKER,
    },
  }));
  for (const course of courses) documents.push({
    collection: 'courses', id: course.id,
    data: { ...course, programme: 'DIT', description: null, dataClassification: SYNTHETIC_MARKER },
  });

  for (const [semesterIndex, semesterId] of SEMESTER_IDS.entries()) {
    for (const [courseIndex, course] of courses.slice(0, 2).entries()) {
      for (const groupId of ['G01', 'G02']) {
        const offeringId = `${semesterId}_${course.id}_${groupId}`;
        documents.push({
          collection: 'courseOfferings', id: offeringId,
          data: {
            courseId: course.id,
            semesterId,
            academicSession: ACADEMIC_SESSION,
            semesterNumber: semesterIndex + 1,
            lecturerUid: input.lecturerUid,
            groupId,
            schedule: [scheduleEntry(course, groupId, input.lecturerUid, courseIndex)],
            venue: scheduleEntry(course, groupId, input.lecturerUid, courseIndex).venue,
            status: 'representative_synthetic',
            confirmationStatus: 'pending_official_offering',
            dataClassification: SYNTHETIC_MARKER,
          },
        });
        input.studentUids.forEach((studentUid, studentIndex) => {
          if (studentIndex !== (groupId === 'G01' ? 0 : 1)) return;
          documents.push({
            collection: 'enrollments', id: enrollmentDocumentId(offeringId, studentUid),
            data: {
              studentUid,
              courseOfferingId: offeringId,
              courseId: course.id,
              semesterId,
              academicSession: ACADEMIC_SESSION,
              groupId,
              status: 'enrolled',
              dataClassification: SYNTHETIC_MARKER,
            },
          });
        });
      }
    }
  }
  return documents;
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    return `{${Object.keys(record).sort().map((key) => `${JSON.stringify(key)}:${canonical(record[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

/** Create-only writes make retries safe and never overwrite conflicting data. */
export async function seedSyntheticAcademicDataset(
  store: AcademicSeedStore,
  documents: readonly DatasetDocument[],
): Promise<{ created: number; alreadyPresent: number }> {
  let created = 0;
  let alreadyPresent = 0;
  for (const document of documents) {
    const existing = await store.get(document.collection, document.id);
    if (existing) {
      if (canonical(existing) !== canonical(document.data)) {
        throw new Error(`Refusing to overwrite conflicting ${document.collection}/${document.id}.`);
      }
      alreadyPresent += 1;
      continue;
    }
    try {
      await store.create(document.collection, document.id, document.data);
      created += 1;
    } catch (error) {
      const raced = await store.get(document.collection, document.id);
      if (!raced || canonical(raced) !== canonical(document.data)) {
        throw new Error(`Could not safely create ${document.collection}/${document.id}.`, { cause: error });
      }
      alreadyPresent += 1;
    }
  }
  return { created, alreadyPresent };
}
