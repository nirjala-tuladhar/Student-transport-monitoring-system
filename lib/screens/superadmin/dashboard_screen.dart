import 'package:flutter/material.dart';
import '../../supabase_client.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  State<SuperadminDashboardScreen> createState() =>
      _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  List<Map<String, dynamic>> schoolAdmins = []; // fetched school_admin table
  List<Map<String, dynamic>> schools = []; // fetched schools table
  bool loadingAdmins = true;
  bool loadingSchools = true;

  @override
  void initState() {
    super.initState();
    fetchSchoolAdmins();
    fetchSchools();
  }

  Future<void> fetchSchoolAdmins() async {
    setState(() => loadingAdmins = true);
    try {
      final response = await supabase.from('school_admin').select();
      schoolAdmins = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching school admins: $e');
      schoolAdmins = [];
    }
    setState(() => loadingAdmins = false);
  }

  Future<void> fetchSchools() async {
    setState(() => loadingSchools = true);
    try {
      final response = await supabase.from('schools').select();
      schools = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching schools: $e');
      schools = [];
    }
    setState(() => loadingSchools = false);
  }

  void logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void resetPassword() async {
    final userEmail = supabase.auth.currentUser?.email;
    if (userEmail != null) {
      await supabase.auth.resetPasswordForEmail(userEmail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Password Reset
              Card(
                elevation: 4,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: const Text('Reset Password'),
                  trailing: ElevatedButton(
                    onPressed: resetPassword,
                    child: const Text('Send Link'),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // School Admin List with Edit/Delete
              Card(
                elevation: 6,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('School Admins',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      loadingAdmins
                          ? const Center(child: CircularProgressIndicator())
                          : schoolAdmins.isEmpty
                              ? const Text('No school admins found.')
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: schoolAdmins.length,
                                  itemBuilder: (context, index) {
                                    final admin = schoolAdmins[index];
                                    return ListTile(
                                      title: Text(
                                          admin['school_name'] ?? 'Unnamed'),
                                      subtitle: Text(admin['email'] ?? ''),
                                      trailing: Wrap(
                                        spacing: 10,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () {
                                              // TODO: implement edit school admin
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () async {
                                              // Delete school admin from table
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Confirm Delete'),
                                                  content: const Text(
                                                      'Are you sure you want to delete this school admin?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child:
                                                          const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                try {
                                                  await supabase
                                                      .from('school_admin')
                                                      .delete()
                                                      .eq('id', admin['id']);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(const SnackBar(
                                                          content: Text(
                                                              'School admin deleted')));
                                                  await fetchSchoolAdmins(); // refresh list
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Delete failed: $e')));
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Create School Admin
              Card(
                elevation: 6,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: const Text('Create School Admin'),
                  subtitle:
                      const Text('Generate temp login and assign to school'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Navigate and wait for result, refresh list after return
                      final result = await Navigator.pushNamed(
                          context, '/create_school_admin');
                      if (result == true) {
                        await fetchSchoolAdmins();
                        await fetchSchools();
                      }
                    },
                    child: const Text('Create'),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Summary Section
              Card(
                elevation: 6,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Summary',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      Text('Total Schools: ${schools.length}'),
                      const SizedBox(height: 10),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(2),
                        },
                        border: TableBorder.all(color: Colors.grey),
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Colors.blueGrey),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('School',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Students',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Drivers',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Address',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                          ...schools.map(
                            (school) => TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(school['name'] ?? ''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child:
                                      Text('${school['student_count'] ?? 0}'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('${school['driver_count'] ?? 0}'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(school['address'] ?? ''),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
