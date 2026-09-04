import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spor Salonu Yönetimi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF6B00),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// VERİTABANI YARDIMCISI (SQLite)
// -----------------------------------------------------------------------------
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gym_members.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        phone TEXT NOT NULL,
        membershipType TEXT NOT NULL,
        startDate TEXT NOT NULL,
        isPaid INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertMember(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('members', row);
  }

  Future<List<Map<String, dynamic>>> getMembers() async {
    final db = await instance.database;
    return await db.query('members', orderBy: 'id DESC');
  }

  Future<int> updatePaymentStatus(int id, int isPaid) async {
    final db = await instance.database;
    return await db.update(
      'members',
      {'isPaid': isPaid},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMember(int id) async {
    final db = await instance.database;
    return await db.delete(
      'members',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// -----------------------------------------------------------------------------
// ANA EKRAN (DASHBOARD)
// -----------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshMemberList();
  }

  Future<void> _refreshMemberList() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getMembers();
    setState(() {
      _members = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalMembers = _members.length;
    int paidMembers = _members.where((m) => m['isPaid'] == 1).length;
    int unpaidMembers = totalMembers - paidMembers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spor Salonu Yönetimi', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMemberList,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Genel Durum',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard('Toplam Üye', '$totalMembers', Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatCard('Ödeyenler', '$paidMembers', const Color(0xFF00E676)),
                      const SizedBox(width: 8),
                      _buildStatCard('Borçlular', '$unpaidMembers', Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Üye Listesi',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddMemberScreen()),
                          );
                          _refreshMemberList();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Üye'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _members.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Text('Henüz kayıtlı üye bulunmamaktadır.', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final bool isPaid = member['isPaid'] == 1;

                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPaid ? const Color(0xFF00E676) : Colors.redAccent,
                                  child: Icon(
                                    isPaid ? Icons.check : Icons.priority_high,
                                    color: Colors.black,
                                  ),
                                ),
                                title: Text(
                                  member['fullName'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Tel: ${member['phone']}\nPaket: ${member['membershipType']} | Tarih: ${member['startDate']}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'toggle') {
                                      await DatabaseHelper.instance.updatePaymentStatus(
                                        member['id'],
                                        isPaid ? 0 : 1,
                                      );
                                      _refreshMemberList();
                                    } else if (value == 'delete') {
                                      await DatabaseHelper.instance.deleteMember(member['id']);
                                      _refreshMemberList();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(isPaid ? 'Borçlu İşaretle' : 'Ödendi İşaretle'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Üyeyi Sil', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 8),
            Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// YENİ ÜYE EKLEME EKRANI
// -----------------------------------------------------------------------------
class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedType = 'Aylık';
  DateTime _selectedDate = DateTime.now();
  bool _isPaid = true;

  Future<void> _saveMember() async {
    if (_formKey.currentState!.validate()) {
      final newMember = {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'membershipType': _selectedType,
        'startDate': DateFormat('dd/MM/yyyy').format(_selectedDate),
        'isPaid': _isPaid ? 1 : 0,
      };

      await DatabaseHelper.instance.insertMember(newMember);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Üye Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Color(0xFFFF6B00)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Lütfen ad soyad girin' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon Numarası',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: Color(0xFFFF6B00)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Lütfen telefon girin' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Üyelik Tipi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_membership, color: Color(0xFFFF6B00)),
                ),
                items: ['Aylık', '3 Aylık', '6 Aylık', 'Yıllık']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                leading: const Icon(Icons.calendar_today, color: Color(0xFFFF6B00)),
                title: Text('Başlangıç: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Ödeme Alındı mı?'),
                activeColor: const Color(0xFF00E676),
                value: _isPaid,
                onChanged: (value) => setState(() => _isPaid = value),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saveMember,
                  child: const Text('KAYDET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
