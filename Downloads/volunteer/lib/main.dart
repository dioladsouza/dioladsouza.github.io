import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Added Maps Import

void main() {
  runApp(const VolunteerApp());
}

class VolunteerApp extends StatelessWidget {
  const VolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volunteer Match-30',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DiscoveryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- MOCK DATA (Now with Latitude & Longitude) ---
final List<Map<String, dynamic>> mockTasks = [
  {"id": "1", "title": "Help with Trig Homework", "category": "education", "duration": 20, "xp": 200, "verified": true, "distance": "0.5 mi", "lat": 37.3541, "lng": -121.9552},
  {"id": "2", "title": "Carry Groceries to 3rd Floor", "category": "physical", "duration": 10, "xp": 100, "verified": false, "distance": "0.2 mi", "lat": 37.3610, "lng": -121.9620},
  {"id": "3", "title": "Walk Golden Retriever", "category": "physical", "duration": 30, "xp": 300, "verified": true, "distance": "1.1 mi", "lat": 37.3480, "lng": -121.9480},
  {"id": "4", "title": "Fix Wi-Fi Router", "category": "tech", "duration": 15, "xp": 150, "verified": true, "distance": "0.8 mi", "lat": 37.3580, "lng": -121.9500},
];

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  String searchQuery = "";
  String activeFilter = "all";
  String viewMode = "list"; 
  List<String> claimedIds = [];
  int totalXP = 1250; 
  int currentNavIndex = 0; // Tracks which tab is active

  // Filtering Logic
  List<Map<String, dynamic>> get filteredTasks {
    return mockTasks.where((task) {
      if (claimedIds.contains(task['id'])) return false; 
      if (searchQuery.isNotEmpty && !task['title'].toString().toLowerCase().contains(searchQuery.toLowerCase())) return false;
      if (activeFilter == "under10" && task['duration'] > 10) return false;
      if (activeFilter == "education" && task['category'] != "education") return false;
      if (activeFilter == "physical" && task['category'] != "physical") return false;
      if (activeFilter == "verified" && task['verified'] != true) return false;
      return true;
    }).toList();
  }

  void handleClaim(String id, int xp) {
    setState(() {
      claimedIds.add(id);
      totalXP += xp;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Task Claimed! +$xp XP Added"), backgroundColor: Colors.teal.shade700)
    );
  }

  void _showTaskDetailSheet(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(task['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  if (task['verified']) const Icon(Icons.verified, color: Colors.blue)
                ],
              ),
              const SizedBox(height: 8),
              Text("${task['distance']} away • ${task['duration']} mins", style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amber),
                  Text("Reward: ${task['xp']} XP", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    Navigator.pop(context);
                    handleClaim(task['id'], task['xp']);
                  },
                  child: const Text("Claim Task", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // --- TAB RESPONSIVENESS LOGIC ---
  // Returns the correct screen based on the bottom nav selection
  Widget _buildBody() {
    switch (currentNavIndex) {
      case 0:
        return _buildDiscoverTab(); // The main map/list view
      case 1:
        return _buildMyTasksTab(); // The active tasks list
      case 2:
        return _buildProfileTab(); // User profile & stats
      default:
        return _buildDiscoverTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text("Volunteer Match-30", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 18),
                Text("$totalXP", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      // Here we load the body dynamically based on the current tab
      body: _buildBody(), 
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentNavIndex,
        onTap: (index) => setState(() => currentNavIndex = index), // Updates the screen
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Discover"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: "My Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: DISCOVER (List & Map)
  // ==========================================
  Widget _buildDiscoverTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                hintText: "Search tasks nearby...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        // View Toggle & Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Nearby Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.list, color: viewMode == "list" ? Colors.teal : Colors.grey),
                      onPressed: () => setState(() => viewMode = "list"),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: Icon(Icons.map, color: viewMode == "map" ? Colors.teal : Colors.grey),
                      onPressed: () => setState(() => viewMode = "map"),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilter("All", "all"),
              const SizedBox(width: 8),
              _buildFilter("Under 10 mins", "under10"),
              const SizedBox(width: 8),
              _buildFilter("Education", "education"),
              const SizedBox(width: 8),
              _buildFilter("Physical", "physical"),
            ],
          ),
        ),
        
        // Dynamic Content Area (List vs Real Map)
        Expanded(
          child: viewMode == "map" 
            ? _buildGoogleMap() 
            : _buildListView(),
        ),

        // Active Tasks Banner
        if (claimedIds.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => currentNavIndex = 1), // Auto-navigates to "My Tasks"
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200)
              ),
              child: Row(
                children: [
                  const Text("🎯 ", style: TextStyle(fontSize: 18)),
                  Text("${claimedIds.length} Active Task${claimedIds.length > 1 ? 's' : ''}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                  const Spacer(),
                  const Text("View →", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
      ],
    );
  }

  // --- GOOGLE MAPS WIDGET ---
  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.3541, -121.9552), // Default Center Camera
        zoom: 14,
      ),
      myLocationEnabled: true,
      markers: filteredTasks.map((task) => Marker(
        markerId: MarkerId(task['id']),
        position: LatLng(task['lat'], task['lng']),
        infoWindow: InfoWindow(
          title: task['title'],
          snippet: "${task['duration']} mins • Tap to claim",
          onTap: () => _showTaskDetailSheet(task), // Clicking map pin opens Bottom Sheet
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          task['category'] == 'education' ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange
        ),
      )).toSet(),
    );
  }

  Widget _buildListView() {
    if (filteredTasks.isEmpty) return const Center(child: Text("No tasks match your filters."));
    
    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            onTap: () => _showTaskDetailSheet(task),
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade50,
              child: Icon(
                task['category'] == 'education' ? Icons.school : task['category'] == 'tech' ? Icons.computer : Icons.fitness_center,
                color: Colors.teal,
              )
            ),
            title: Row(
              children: [
                Expanded(child: Text(task['title'], style: const TextStyle(fontWeight: FontWeight.bold))),
                if (task['verified']) const Icon(Icons.verified, color: Colors.blue, size: 16)
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("${task['distance']} • ${task['duration']} mins"),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilter(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: activeFilter == value,
      onSelected: (_) => setState(() => activeFilter = value),
      backgroundColor: Colors.white,
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal.shade900,
      side: BorderSide(color: activeFilter == value ? Colors.teal : Colors.grey.shade300),
    );
  }

  // ==========================================
  // TAB 1: MY TASKS (Placeholder)
  // ==========================================
  Widget _buildMyTasksTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text("You have ${claimedIds.length} active tasks", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Complete them to earn your XP!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PROFILE (Placeholder)
  // ==========================================
  // ==========================================
  // TAB 2: PROFILE (Matching the UI Design)
  // ==========================================
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(),
                const SizedBox(height: 24),
                
                // Badges Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Badges", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("6/9 unlocked", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBadgesGrid(),
                
                const SizedBox(height: 24),
                
                // Skills Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Skills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("Edit Skills"),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue.shade600),
                    )
                  ],
                ),
                _buildSkillsWrap(),
                
                const SizedBox(height: 24),
                
                // Settings Tile
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)
                  ),
                  child: const ListTile(
                    title: Text("Account Settings", style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24), // Bottom padding
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- PROFILE HELPER WIDGETS ---

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF2476D2), // Matching the blue header
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: const Center(
                  child: Text("AJ", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Name", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("Level 5", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      const Text("Neighborhood Hero", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          // Progress Bar Area
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("3,450 / 5,000 XP", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
              Text("Level 6", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 3450 / 5000,
            backgroundColor: Colors.black.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          )
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(Icons.workspace_premium_outlined, "23", "Tasks Completed", Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard(Icons.schedule, "485", "Minutes Donated", Colors.green),
        const SizedBox(width: 12),
        _buildStatCard(Icons.bolt, "3,450", "Points Earned", Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesGrid() {
    final badges = [
      {"title": "First 5-Star", "icon": Icons.star_border, "unlocked": true},
      {"title": "Weekend Warrior", "icon": Icons.military_tech_outlined, "unlocked": true},
      {"title": "Speed Demon", "icon": Icons.bolt, "unlocked": true},
      {"title": "Kind Heart", "icon": Icons.favorite_border, "unlocked": true},
      {"title": "Team Player", "icon": Icons.people_outline, "unlocked": true},
      {"title": "Delivery Pro", "icon": Icons.inventory_2_outlined, "unlocked": false},
      {"title": "Math Whiz", "icon": Icons.calculate_outlined, "unlocked": true},
      {"title": "Strong Helper", "icon": Icons.fitness_center, "unlocked": false},
      {"title": "Tech Guru", "icon": Icons.code, "unlocked": false},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final bool isUnlocked = badge["unlocked"] as bool;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              if (isUnlocked) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked ? Colors.teal.shade50 : Colors.grey.shade100,
                ),
                child: Icon(
                  badge["icon"] as IconData, 
                  color: isUnlocked ? Colors.teal.shade400 : Colors.grey.shade300,
                  size: 24
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge["title"] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                  color: isUnlocked ? Colors.black87 : Colors.grey.shade400,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsWrap() {
    final skills = ["Math", "Lifting", "Coding", "Dog Walking", "Tutoring", "Cooking"];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) => Chip(
        label: Text(skill, style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.teal.shade50,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      )).toList(),
    );
  }
}