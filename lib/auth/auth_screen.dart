import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'package:bookbridgev1/screens/home_screen.dart'; 
import 'package:bookbridgev1/auth/auth%20service/auth_service.dart';

class AuthApp extends StatelessWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get AuthService using Provider instead of the global variable
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      // Use the authService instance directly
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen(); // user is logged in
        }
        return const LoginScreen(); // user is NOT logged in
      },
    );
  }
}