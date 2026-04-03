import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Utility to sync user roles from drivers collection to users collection
/// Run this once to fix any existing role mismatches
class SyncUserRoles {
  static final _firestore = FirebaseFirestore.instance;

  /// Sync all driver roles: Check drivers collection and update users collection
  /// Returns: number of users updated
  static Future<int> syncAllDriverRoles() async {
    try {
      debugPrint('🔄 Starting driver role sync...');

      // Get all drivers
      final driversSnapshot = await _firestore.collection('drivers').get();
      debugPrint('📋 Found ${driversSnapshot.docs.length} drivers');

      int updatedCount = 0;

      for (final driverDoc in driversSnapshot.docs) {
        final driverEmail = driverDoc['email'] as String?;
        if (driverEmail == null || driverEmail.isEmpty) {
          continue;
        }

        // Find user with this email
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: driverEmail)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final currentRole = userDoc['role'] as String? ?? 'passenger';

          // If role is not 'driver', update it
          if (currentRole != 'driver') {
            await userDoc.reference.update({'role': 'driver'});
            debugPrint(
              '✅ Updated $driverEmail from "$currentRole" to "driver"',
            );
            updatedCount++;
          }
        }
      }

      debugPrint('🎉 Sync complete! Updated $updatedCount users');
      return updatedCount;
    } catch (e) {
      debugPrint('❌ Error syncing driver roles: $e');
      rethrow;
    }
  }

  /// Check for mismatches and return list of emails with wrong roles
  static Future<List<String>> checkMismatches() async {
    try {
      debugPrint('🔍 Checking for role mismatches...');
      final mismatches = <String>[];

      // Get all drivers
      final driversSnapshot = await _firestore.collection('drivers').get();

      for (final driverDoc in driversSnapshot.docs) {
        final driverEmail = driverDoc['email'] as String?;
        if (driverEmail == null || driverEmail.isEmpty) {
          continue;
        }

        // Find user with this email
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: driverEmail)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userRole =
              userQuery.docs.first['role'] as String? ?? 'passenger';

          // If role is not 'driver', it's a mismatch
          if (userRole != 'driver') {
            mismatches.add(
              '$driverEmail (current role: $userRole, should be: driver)',
            );
          }
        }
      }

      if (mismatches.isEmpty) {
        debugPrint('✅ No role mismatches found!');
      } else {
        debugPrint('⚠️ Found ${mismatches.length} role mismatches:');
        for (final mismatch in mismatches) {
          debugPrint('  - $mismatch');
        }
      }

      return mismatches;
    } catch (e) {
      debugPrint('❌ Error checking mismatches: $e');
      rethrow;
    }
  }
}
