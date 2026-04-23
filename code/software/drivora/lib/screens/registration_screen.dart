import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _carModelController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.darkBackground, AppTheme.darkSurface.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  const Text('JOIN DRIVORA', 
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryNeon, letterSpacing: 2)),
                  const Text('ENTER YOUR VEHICLE DETAILS', 
                    style: TextStyle(fontSize: 12, color: Colors.white38, letterSpacing: 1.5)),
                  const SizedBox(height: 50),
                  
                  _buildTextField('FULL NAME', Icons.person_outline, _nameController),
                  const SizedBox(height: 20),
                  _buildTextField('EMAIL ADDRESS', Icons.email_outlined, _emailController),
                  const SizedBox(height: 20),
                  _buildTextField('VEHICLE MODEL', Icons.directions_car_filled_outlined, _carModelController),
                  
                  const SizedBox(height: 60),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNeon,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 10,
                        shadowColor: AppTheme.primaryNeon.withOpacity(0.5),
                      ),
                      child: const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: AppTheme.primaryNeon, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppTheme.primaryNeon),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (value) => value!.isEmpty ? 'FIELD REQUIRED' : null,
    );
  }
}
