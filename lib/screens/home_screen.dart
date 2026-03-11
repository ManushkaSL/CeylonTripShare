import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/widgets/tour_card.dart';
import 'package:trip_share_app/screens/joined_tours_screen.dart';
import 'package:trip_share_app/screens/chats_list_screen.dart';
import 'package:trip_share_app/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Sample tour data
  final List<Tour> _tours = [
    Tour(
      name: 'Sigiriya Rock Fortress',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Sigiriya_%28_Lion_Rock_%29.jpg/800px-Sigiriya_%28_Lion_Rock_%29.jpg',
      startDate: DateTime(2026, 3, 15, 7, 30),
      totalSeats: 12,
      remainingSeats: 12,
      price: 150,
      category: 'Heritage & Culture',
      description:
          'Climb the iconic Sigiriya Rock Fortress, a UNESCO World Heritage Site rising 200 meters above the surrounding plains. Explore the ancient frescoes of the Sigiriya Maidens, walk through the Mirror Wall corridor, and marvel at the Lion\'s Paw entrance before reaching the summit palace ruins with breathtaking 360-degree views of the Sri Lankan countryside.',
      photos: [
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Sigiriya_%28_Lion_Rock_%29.jpg/800px-Sigiriya_%28_Lion_Rock_%29.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/SigiriyaFresco.jpg/800px-SigiriyaFresco.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Sigiriya_Lion_Paw.jpg/800px-Sigiriya_Lion_Paw.jpg',
      ],
      startLocation: 'Sigiriya Parking Area',
      lastJoiningTime: DateTime(2026, 3, 14, 22, 0),
      endTime: '1:00 PM',
      endLocation: 'Sigiriya Parking Area',
      route: [
        RouteStop(location: 'Sigiriya Parking Area', time: '7:30 AM'),
        RouteStop(location: 'Boulder Gardens', time: '8:00 AM'),
        RouteStop(location: 'Frescoes & Mirror Wall', time: '9:00 AM'),
        RouteStop(location: 'Lion\'s Paw Terrace', time: '10:00 AM'),
        RouteStop(location: 'Summit Palace Ruins', time: '10:30 AM'),
        RouteStop(location: 'Sigiriya Parking Area', time: '1:00 PM'),
      ],
      operatorName: 'Ceylon Heritage Tours',
      whatsIncluded: [
        'Entry Tickets',
        'Professional Guide',
        'Bottled Water',
        'Light Breakfast',
      ],
      tourFeatures: [
        'UNESCO World Heritage Site',
        'Expert Historian Guide',
        'Small Group Experience',
      ],
    ),
    Tour(
      name: 'Ella Nine Arches Bridge',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Nine_Arch_Bridge%2C_Ella%2C_Sri_Lanka.jpg/800px-Nine_Arch_Bridge%2C_Ella%2C_Sri_Lanka.jpg',
      startDate: DateTime(2026, 3, 18, 6, 0),
      totalSeats: 8,
      remainingSeats: 3,
      price: 120,
      category: 'Nature & Scenic',
      description:
          'Experience the stunning Nine Arches Bridge in Ella, one of the finest examples of colonial-era railway construction in Sri Lanka. Walk along scenic tea plantation trails to reach this architectural marvel set amidst lush green hills. Watch trains cross the bridge and enjoy panoramic views of the Ella Gap valley.',
      photos: [
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Nine_Arch_Bridge%2C_Ella%2C_Sri_Lanka.jpg/800px-Nine_Arch_Bridge%2C_Ella%2C_Sri_Lanka.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Ella_Gap_Sri_Lanka.jpg/800px-Ella_Gap_Sri_Lanka.jpg',
      ],
      startLocation: 'Ella Town Center',
      lastJoiningTime: DateTime(2026, 3, 17, 22, 0),
      endTime: '12:00 PM',
      endLocation: 'Ella Town Center',
      route: [
        RouteStop(location: 'Ella Town Center', time: '6:00 AM'),
        RouteStop(location: 'Tea Plantation Trail', time: '6:30 AM'),
        RouteStop(location: 'Nine Arches Bridge', time: '7:30 AM'),
        RouteStop(location: 'Ella Town Center', time: '12:00 PM'),
      ],
      operatorName: 'Ella Adventures',
      whatsIncluded: ['Guide', 'Tea Tasting', 'Bottled Water', 'Snacks'],
      tourFeatures: [
        'Scenic Trail Walk',
        'Tea Plantation Visit',
        'Photography Spots',
      ],
    ),
    Tour(
      name: 'Galle Fort Heritage Walk',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Galle_Fort_-_Sri_Lanka.jpg/800px-Galle_Fort_-_Sri_Lanka.jpg',
      startDate: DateTime(2026, 3, 20, 8, 0),
      totalSeats: 10,
      remainingSeats: 0,
      price: 100,
      category: 'Heritage Walk',
      description:
          'Stroll through the charming streets of Galle Fort, a UNESCO World Heritage Site built by Portuguese colonizers in the 16th century. Discover Dutch-colonial architecture, visit the iconic lighthouse, explore boutique cafes and art galleries, and walk the historic ramparts with stunning Indian Ocean views.',
      photos: [
        'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Galle_Fort_-_Sri_Lanka.jpg/800px-Galle_Fort_-_Sri_Lanka.jpg',
      ],
      startLocation: 'Galle Fort Main Gate',
      lastJoiningTime: DateTime(2026, 3, 19, 22, 0),
      endTime: '1:00 PM',
      endLocation: 'Galle Fort Main Gate',
      route: [
        RouteStop(location: 'Galle Fort Main Gate', time: '8:00 AM'),
        RouteStop(location: 'Dutch Reformed Church', time: '8:30 AM'),
        RouteStop(location: 'Galle Lighthouse', time: '9:30 AM'),
        RouteStop(location: 'Fort Ramparts', time: '10:30 AM'),
        RouteStop(location: 'Galle Fort Main Gate', time: '1:00 PM'),
      ],
      operatorName: 'Southern Coast Tours',
      whatsIncluded: [
        'Walking Guide',
        'Entry Tickets',
        'Refreshments',
        'Snack',
      ],
      tourFeatures: [
        'UNESCO World Heritage Site',
        'Colonial Architecture',
        'Coastal Views',
      ],
    ),
    Tour(
      name: 'Kandy Temple of the Tooth',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Temple_of_the_Tooth%2C_Kandy.jpg/800px-Temple_of_the_Tooth%2C_Kandy.jpg',
      startDate: DateTime(2026, 3, 22, 9, 0),
      totalSeats: 15,
      remainingSeats: 7,
      price: 180,
      category: 'Cultural & Religious',
      description:
          'Visit the sacred Temple of the Tooth Relic in Kandy, Sri Lanka\'s cultural capital. This revered Buddhist temple houses the relic of the tooth of the Buddha. Explore the Royal Palace complex, enjoy traditional Kandyan dance performances, and take a leisurely walk around the scenic Kandy Lake.',
      photos: [
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Temple_of_the_Tooth%2C_Kandy.jpg/800px-Temple_of_the_Tooth%2C_Kandy.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Kandy_Lake.jpg/800px-Kandy_Lake.jpg',
      ],
      startLocation: 'Kandy City Center',
      lastJoiningTime: DateTime(2026, 3, 21, 22, 0),
      endTime: '4:00 PM',
      endLocation: 'Kandy City Center',
      route: [
        RouteStop(location: 'Kandy City Center', time: '9:00 AM'),
        RouteStop(location: 'Temple of the Tooth', time: '9:30 AM'),
        RouteStop(location: 'Royal Palace Complex', time: '11:00 AM'),
        RouteStop(location: 'Kandy Lake Walk', time: '1:00 PM'),
        RouteStop(location: 'Kandyan Dance Show', time: '2:30 PM'),
        RouteStop(location: 'Kandy City Center', time: '4:00 PM'),
      ],
      operatorName: 'Ceylon Cultural Journeys',
      whatsIncluded: [
        'Entry Tickets',
        'Guide',
        'Sri Lankan Lunch',
        'Kandyan Dance Tickets',
        'Water',
      ],
      tourFeatures: [
        'Sacred Buddhist Temple',
        'Traditional Dance Show',
        'Lakeside Walk',
      ],
    ),
  ];

  List<Tour> get _activeTours => _tours
      .where(
        (t) =>
            t.status == TourStatus.active || t.status == TourStatus.fullBooked,
      )
      .toList();

  List<Tour> get _passiveTours =>
      _tours.where((t) => t.status == TourStatus.idle).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: _selectedIndex == 0,
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _selectedIndex == 0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: AppBar(
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    elevation: 0,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1B5E20,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.travel_explore,
                            color: Color(0xFF1B5E20),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Ceylon Shared Tours',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              elevation: 0,
              title: Text(
                _selectedIndex == 1
                    ? 'Chats'
                    : _selectedIndex == 2
                    ? 'Joined Tours'
                    : 'Profile',
                style: const TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
      body: _buildBody(),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Home', 0),
                  _buildNavItem(Icons.chat_bubble_rounded, 'Chats', 1),
                  _buildNavItem(Icons.luggage_rounded, 'Joined', 2),
                  _buildNavItem(Icons.person_rounded, 'Profile', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return const ChatsListBody();
      case 2:
        return const JoinedToursBody();
      case 3:
        return const ProfileBody();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search destinations, tours...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF1B5E20)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tour list with Active & Passive sections
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              if (_activeTours.isNotEmpty) ...[
                const _SectionHeader(title: 'Active Tours'),
                const SizedBox(height: 10),
                for (int i = 0; i < _activeTours.length; i++) ...[
                  TourCard(tour: _activeTours[i]),
                  if (i < _activeTours.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 24),
              ],
              if (_passiveTours.isNotEmpty) ...[
                const _SectionHeader(title: 'Upcoming Tours'),
                const SizedBox(height: 10),
                for (int i = 0; i < _passiveTours.length; i++) ...[
                  TourCard(tour: _passiveTours[i]),
                  if (i < _passiveTours.length - 1) const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1B5E20) : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1B5E20) : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }
}
