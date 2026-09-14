import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTrainerScreen extends StatefulWidget {
const AddTrainerScreen({super.key});

@override
State<AddTrainerScreen> createState() => _AddTrainerScreenState();
}

class _AddTrainerScreenState extends State<AddTrainerScreen> {
final _formKey = GlobalKey<FormState>();

final _nameController = TextEditingController();
final _emailController = TextEditingController();
final _phoneController = TextEditingController();
final _passwordController = TextEditingController();
final _educationController = TextEditingController();
final _addressController = TextEditingController();

String _selectedRole = 'trainer';
bool _isSaving = false;
String _errorMessage = '';

static const Color primaryGreen = Color(0xFF1B6B4A);
static const Color accentGold = Color(0xFFD4AF37);

Future<void> _saveTrainer() async {
if (!_formKey.currentState!.validate()) return;

setState(() {
_isSaving = true;
_errorMessage = '';
});

FirebaseApp? tempApp;
try {
// Use a temporary secondary Firebase app so creating this new account
// does NOT sign out the currently logged-in Admin.
tempApp = await Firebase.initializeApp(
name: 'tempApp_${DateTime.now().millisecondsSinceEpoch}',
options: Firebase.app().options,
);

final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

final credential = await tempAuth.createUserWithEmailAndPassword(
email: _emailController.text.trim(),
password: _passwordController.text.trim(),
);

final uid = credential.user!.uid;

// Save the profile in Firestore using the MAIN app's connection
await FirebaseFirestore.instance.collection('users').doc(uid).set({
'name': _nameController.text.trim(),
'email': _emailController.text.trim(),
'phone': _phoneController.text.trim(),
'education': _educationController.text.trim(),
'address': _addressController.text.trim(),
'role': _selectedRole,
'isActive': true,
'createdAt': FieldValue.serverTimestamp(),
});

await tempAuth.signOut();

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Staff account created successfully!'),
backgroundColor: primaryGreen,
),
);
Navigator.of(context).pop();
}
} on FirebaseAuthException catch (e) {
setState(() {
if (e.code == 'email-already-in-use') {
_errorMessage = 'An account with this email already exists.';
} else if (e.code == 'weak-password') {
_errorMessage = 'Password should be at least 6 characters.';
} else if (e.code == 'invalid-email') {
_errorMessage = 'Please enter a valid email.';
} else {
_errorMessage = 'Failed: ${e.message}';
}
});
} catch (e) {
setState(() {
_errorMessage = 'Something went wrong. Please try again.';
});
} finally {
if (tempApp != null) {
await tempApp.delete();
}
if (mounted) {
setState(() {
_isSaving = false;
});
}
}
}

InputDecoration _inputStyle(String label, IconData icon) {
return InputDecoration(
labelText: label,
labelStyle: TextStyle(color: Colors.grey[600]),
prefixIcon: Icon(icon, color: primaryGreen),
filled: true,
fillColor: const Color(0xFFF5F7F5),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: BorderSide.none,
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: const BorderSide(color: primaryGreen, width: 1.5),
),
);
}

@override
void dispose() {
_nameController.dispose();
_emailController.dispose();
_phoneController.dispose();
_passwordController.dispose();
_educationController.dispose();
_addressController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF5F7F5),
appBar: AppBar(
backgroundColor: primaryGreen,
elevation: 0,
title: const Text('Add Staff Account'),
),
body: Form(
key: _formKey,
child: ListView(
padding: const EdgeInsets.all(20),
children: [
TextFormField(
controller: _nameController,
decoration: _inputStyle('Full Name', Icons.person_outline),
validator: (v) =>
(v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
),
const SizedBox(height: 14),
TextFormField(
controller: _emailController,
keyboardType: TextInputType.emailAddress,
decoration: _inputStyle('Email (used for login)', Icons.email_outlined),
validator: (v) {
if (v == null || v.trim().isEmpty) return 'Please enter an email';
if (!v.contains('@')) return 'Please enter a valid email';
return null;
},
),
const SizedBox(height: 14),
TextFormField(
controller: _phoneController,
keyboardType: TextInputType.phone,
decoration: _inputStyle('Phone Number', Icons.phone_outlined),
),
const SizedBox(height: 14),
TextFormField(
controller: _educationController,
decoration: _inputStyle('Education (e.g. B.A, ITI, Diploma)', Icons.school_outlined),
),
const SizedBox(height: 14),
TextFormField(
controller: _addressController,
maxLines: 2,
decoration: _inputStyle('Address', Icons.location_on_outlined),
),
const SizedBox(height: 14),
TextFormField(
controller: _passwordController,
obscureText: true,
decoration: _inputStyle('Temporary Password', Icons.lock_outline),
validator: (v) {
if (v == null || v.isEmpty) return 'Please set a password';
if (v.length < 6) return 'Password must be at least 6 characters';
return null;
},
),
const SizedBox(height: 14),
DropdownButtonFormField<String>(
initialValue: _selectedRole,
decoration: _inputStyle('Role', Icons.badge_outlined),
items: const [
DropdownMenuItem(value: 'trainer', child: Text('Trainer')),
DropdownMenuItem(value: 'placementOfficer', child: Text('Placement Officer')),
DropdownMenuItem(value: 'mobilizer', child: Text('Mobilizer')),
DropdownMenuItem(value: 'admin', child: Text('Admin')),
],
onChanged: (value) {
setState(() {
_selectedRole = value!;
});
},
),
if (_errorMessage.isNotEmpty) ...[
const SizedBox(height: 16),
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.red[50],
borderRadius: BorderRadius.circular(8),
),
child: Text(
_errorMessage,
style: TextStyle(color: Colors.red[700], fontSize: 13),
),
),
],
const SizedBox(height: 28),
SizedBox(
height: 50,
child: ElevatedButton(
onPressed: _isSaving ? null : _saveTrainer,
style: ElevatedButton.styleFrom(
backgroundColor: primaryGreen,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
),
child: _isSaving
? const SizedBox(
height: 22,
width: 22,
child: CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2.5,
),
)
    : const Text(
'Create Account',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
color: Colors.white,
),
),
),
),
],
),
),
);
}
}
