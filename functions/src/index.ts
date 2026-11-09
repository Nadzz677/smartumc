import { initializeApp } from 'firebase-admin/app';

// Initialize the Admin SDK once for trusted backend modules.
// No callable operations are exposed until their authorization and data
// contracts have been reviewed and implemented.
initializeApp();

export {
  closeAttendanceSession,
  createAttendanceSession,
  getAttendanceQr,
  getLecturerSessionAttendance,
  openAttendanceSession,
  submitAttendance,
} from './attendance';
