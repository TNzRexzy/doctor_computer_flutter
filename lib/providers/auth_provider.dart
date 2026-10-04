import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _currentUser = UserModel(
      id: 'USR-123',
      fullName: 'John Doe',
      email: email,
      phone: '081234567890',
      address: 'Jl. Contoh Alamat No. 123',
      city: 'Jakarta',
      membershipTier: MembershipTier.bronze,
      points: 1500,
      joinDate: DateTime.now().subtract(const Duration(days: 100)),
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register(String name, String email, String phone, String password) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _currentUser = UserModel(
      id: 'USR-124',
      fullName: name,
      email: email,
      phone: phone,
      address: '',
      city: '',
      membershipTier: MembershipTier.bronze,
      points: 0,
      joinDate: DateTime.now(),
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  void updateProfile(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }
}
