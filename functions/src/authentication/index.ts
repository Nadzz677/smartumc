import { UserRecord } from 'firebase-admin/auth';
import { UserRole, requireUserRole } from '../authorization';

const STUDENT_MATRIC_PATTERN = /^[a-z0-9][a-z0-9-]{3,19}$/;
const SYNTHETIC_EMAIL_PATTERN = /^[^@\s]+@(?:[a-z0-9-]+\.)*smartumc\.invalid$/i;

export function normalizeMatricNumber(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Enter a valid matric number.');
  const normalized = value.trim().toLowerCase();
  if (!STUDENT_MATRIC_PATTERN.test(normalized)) {
    throw new Error('Enter a valid matric number.');
  }
  return normalized;
}

export function studentEmailAlias(matricNumber: unknown): string {
  return `${normalizeMatricNumber(matricNumber)}@students.smartumc.invalid`;
}

export interface ProvisionSyntheticUserRequest {
  role: unknown;
  email?: unknown;
  matricNumber?: unknown;
  password: unknown;
  displayName: unknown;
}

export interface UserProfile {
  role: UserRole;
  status: 'active';
  email: string;
  displayName: string;
  matricNumber?: string;
  createdAt?: unknown;
  updatedAt: unknown;
}

export interface ProvisioningDependencies {
  auth: {
    getUserByEmail(email: string): Promise<UserRecord | null>;
    createUser(input: {
      email: string;
      password: string;
      displayName: string;
      disabled: boolean;
    }): Promise<UserRecord>;
    setCustomUserClaims(uid: string, claims: Record<string, unknown>): Promise<void>;
    deleteUser(uid: string): Promise<void>;
  };
  profiles: {
    get(uid: string): Promise<Record<string, unknown> | null>;
    set(uid: string, profile: UserProfile): Promise<void>;
    delete(uid: string): Promise<void>;
  };
  serverTimestamp(): unknown;
}

export interface ProvisionedUser {
  uid: string;
  email: string;
  role: UserRole;
  matricNumber?: string;
  reconciled: boolean;
}

function validateProvisionRequest(request: ProvisionSyntheticUserRequest): {
  role: UserRole;
  email: string;
  password: string;
  displayName: string;
  matricNumber?: string;
} {
  const role = requireUserRole(request.role);
  const displayName = typeof request.displayName === 'string' ? request.displayName.trim() : '';
  const password = typeof request.password === 'string' ? request.password : '';
  if (!displayName || password.length < 6) {
    throw new Error('A display name and a Firebase-compatible password are required.');
  }

  let email: string;
  let matricNumber: string | undefined;
  if (role === 'student') {
    matricNumber = normalizeMatricNumber(request.matricNumber);
    email = studentEmailAlias(matricNumber);
    if (typeof request.email === 'string' && request.email.trim().toLowerCase() !== email) {
      throw new Error('Student email must be the generated matric alias.');
    }
  } else {
    email = typeof request.email === 'string' ? request.email.trim().toLowerCase() : '';
    if (!SYNTHETIC_EMAIL_PATTERN.test(email)) {
      throw new Error('Staff and Super Admin accounts must use a synthetic smartumc.invalid email.');
    }
    if (request.matricNumber != null && request.matricNumber !== '') {
      throw new Error('Only student accounts may have a matric number.');
    }
  }

  return { role, email, password, displayName, matricNumber };
}

/**
 * Trusted-only account provisioning. Callers must be an operator process using
 * Firebase Admin credentials; this function is never exported as a client API.
 * Existing consistent users are safe to retry. Partial writes are reconciled.
 */
export async function provisionSyntheticUser(
  dependencies: ProvisioningDependencies,
  request: ProvisionSyntheticUserRequest,
): Promise<ProvisionedUser> {
  const input = validateProvisionRequest(request);
  const existingUser = await dependencies.auth.getUserByEmail(input.email);
  let user = existingUser;
  let createdByThisCall = false;

  if (user?.disabled) throw new Error('Disabled synthetic accounts require an explicit administrative review.');

  if (!user) {
    user = await dependencies.auth.createUser({
      email: input.email,
      password: input.password,
      displayName: input.displayName,
      disabled: false,
    });
    createdByThisCall = true;
  }

  const previousClaims = user.customClaims ?? {};
  let previousProfile: Record<string, unknown> | null = null;
  let profileReadCompleted = false;
  let claimsWriteAttempted = false;
  try {
    previousProfile = await dependencies.profiles.get(user.uid);
    profileReadCompleted = true;
    if (
      previousProfile &&
      (previousProfile.role !== input.role ||
        previousProfile.status !== 'active' ||
        previousProfile.email !== input.email ||
        (previousProfile.matricNumber ?? undefined) !== input.matricNumber)
    ) {
      throw new Error('An existing profile conflicts with this provisioning request.');
    }

    const claims = { ...previousClaims, role: input.role, active: true };
    const profile: UserProfile = {
      role: input.role,
      status: 'active',
      email: input.email,
      displayName: input.displayName,
      ...(input.matricNumber ? { matricNumber: input.matricNumber } : {}),
      ...(previousProfile?.createdAt ? {} : { createdAt: dependencies.serverTimestamp() }),
      updatedAt: dependencies.serverTimestamp(),
    };

    claimsWriteAttempted = true;
    await dependencies.auth.setCustomUserClaims(user.uid, claims);
    await dependencies.profiles.set(user.uid, profile);
    return {
      uid: user.uid,
      email: input.email,
      role: input.role,
      ...(input.matricNumber ? { matricNumber: input.matricNumber } : {}),
      reconciled: !createdByThisCall,
    };
  } catch (cause) {
    const rollbackFailures: unknown[] = [];
    if (claimsWriteAttempted && !createdByThisCall) {
      try {
        await dependencies.auth.setCustomUserClaims(user.uid, previousClaims);
      } catch (error) {
        rollbackFailures.push(error);
      }
    }
    if (createdByThisCall || (profileReadCompleted && !previousProfile)) {
      try {
        await dependencies.profiles.delete(user.uid);
      } catch (error) {
        rollbackFailures.push(error);
      }
    }
    if (createdByThisCall) {
      try {
        await dependencies.auth.deleteUser(user.uid);
      } catch (error) {
        rollbackFailures.push(error);
      }
    }
    const detail = rollbackFailures.length
      ? ` Manual reconciliation is required for UID ${user.uid}.`
      : '';
    throw new Error(`Synthetic account provisioning failed.${detail}`, { cause });
  }
}
