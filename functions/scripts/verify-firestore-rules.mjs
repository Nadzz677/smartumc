const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const emulatorUrl = new URL(
  `http://${emulatorHost}/v1/projects/demo-smartumc/databases/(default)/documents/users/mission05-rule-probe`,
);

if (!['127.0.0.1', 'localhost', '[::1]'].includes(emulatorUrl.hostname)) {
  throw new Error('Refusing to send the rules probe anywhere except a local emulator.');
}

const response = await fetch(emulatorUrl);
const result = await response.json().catch(() => ({}));

if (response.status !== 403 || result.error?.status !== 'PERMISSION_DENIED') {
  throw new Error(
    `Expected Firestore Rules to deny an unauthenticated read; received HTTP ${response.status} (${result.error?.status ?? 'unknown status'}).`,
  );
}

console.log('PASS: Firestore Emulator denied the unauthenticated read as expected.');
