export const USER_ROLES = ['student', 'lecturer', 'super_admin'] as const;
export type UserRole = (typeof USER_ROLES)[number];

export function parseUserRole(value: unknown): UserRole | null {
  return typeof value === 'string' && USER_ROLES.includes(value as UserRole)
    ? (value as UserRole)
    : null;
}

export function requireUserRole(value: unknown): UserRole {
  const role = parseUserRole(value);
  if (!role) throw new Error('Unsupported SmartUMC role.');
  return role;
}
