import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_computer/data/models/user_model.dart';

void main() {
  group('UserModel.resolveRole', () {
    test('explicit database admin wins for any email', () {
      expect(UserModel.resolveRole('admin', email: 'someone@example.com'), UserRole.admin);
      expect(UserModel.resolveRole('ADMIN', email: 'someone@example.com'), UserRole.admin);
    });

    test('explicit database cashier is honoured', () {
      expect(UserModel.resolveRole('cashier', email: 'someone@example.com'), UserRole.cashier);
    });

    test('regular customer stays on UserRole.user', () {
      expect(UserModel.resolveRole('user', email: 'buyer@example.com'), UserRole.user);
      expect(UserModel.resolveRole(null, email: 'buyer@example.com'), UserRole.user);
    });

    test('owner account is never demoted by a stale "user" row', () {
      expect(UserModel.resolveRole('user', email: 'nopal48@gmail.com'), UserRole.admin);
      expect(UserModel.resolveRole(null, email: 'nopal48@gmail.com'), UserRole.admin);
      expect(
        UserModel.resolveRole('user', email: '  NOPAL48@Gmail.com '),
        UserRole.admin,
      );
    });

    test('built-in staff accounts keep their role', () {
      expect(
        UserModel.resolveRole('user', email: 'admin@doctorcomputer.id'),
        UserRole.admin,
      );
      expect(
        UserModel.resolveRole(null, email: 'cashier@doctorcomputer.id'),
        UserRole.cashier,
      );
      // Legacy username aliases used by the login form.
      expect(UserModel.resolveRole(null, email: 'admin'), UserRole.admin);
      expect(UserModel.resolveRole(null, email: 'cashier'), UserRole.cashier);
    });

    test('email allowlist is case insensitive and whitespace tolerant', () {
      expect(UserModel.resolveRole(null, email: ' Admin@DoctorComputer.ID '), UserRole.admin);
      expect(UserModel.normalizeEmail(' Nopal48@Gmail.com '), 'nopal48@gmail.com');
    });
  });

  group('UserModel.fromMap role mapping', () {
    Map<String, dynamic> row({String? role, String? email}) {
      final map = <String, dynamic>{
        'id': 'uid-1',
        'full_name': 'Nopal',
        'email': email ?? 'nopal48@gmail.com',
        'phone': '',
        'address': '',
        'city': '',
        'membership_tier': 'platinum',
        'points': 0,
        'join_date': '2026-01-01T00:00:00.000Z',
      };
      // Omitted entirely when null, simulating a profile row from a schema
      // revision that predates the `role` column.
      if (role != null) map['role'] = role;
      return map;
    }

    test('reads admin from public.users.role', () {
      expect(UserModel.fromMap(row(role: 'admin')).role, UserRole.admin);
    });

    test('owner profile without role column resolves as admin', () {
      expect(UserModel.fromMap(row()).role, UserRole.admin);
    });

    test('stale user role does not demote the owner', () {
      expect(UserModel.fromMap(row(role: 'user')).role, UserRole.admin);
    });

    test('regular customer profile with user role stays customer', () {
      expect(UserModel.fromMap(row(role: 'user', email: 'buyer@example.com')).role, UserRole.user);
    });

    test('cached session round-trip preserves the admin role', () {
      final admin = UserModel.fromMap(row(role: 'user'));
      final restored = UserModel.fromMap(admin.toMap());

      expect(restored.role, UserRole.admin);
      expect(restored.email, 'nopal48@gmail.com');
    });
  });
}
