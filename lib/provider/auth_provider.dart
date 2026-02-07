import 'package:flutter/material.dart';

import '../api/services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool isLoading = false;
  late BuildContext context;

  Future<void> loginUser(String email, String password) async {
    isLoading = true;
    notifyListeners();

    await ApiService().loginUser(
      email_username: email,
      password: password,
      context: context,
    );

    isLoading = false;
    notifyListeners();
  }
}
