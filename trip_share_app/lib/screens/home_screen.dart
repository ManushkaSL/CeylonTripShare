import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/tour_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/widgets/tour_card.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
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
  final TourService _tourService = TourService();

  @override
  void initState() {
    super.initState();
    // Bookings load automatically when user authenticates
    // This ensures they load even if auth was cached
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) JoinedTourService().loadBookings();
    });
  }

  static final Tour _mockTour = Tour(
    id: 'mock_tour_1',
    name: 'Mock Tour - Ella Day Trip',
    imageUrl:
        'https://images.unsplash.com/photo-1491553895911-0055eca6402d?w=800',
    startDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
    totalSeats: 20,
    remainingSeats: 12,
    price: 45,
    description:
        'Mock tour for testing card tap and detail screen navigation from Home.',
    category: 'Test',
    startLocation: 'Colombo Fort',
    endLocation: 'Colombo Fort',
    operatorName: 'TripShare Test Operator',
  );

  List<Tour> _activeTours(List<Tour> tours) => tours
      .where(
        (t) =>
            t.status == TourStatus.active || t.status == TourStatus.fullBooked,
      )
      .toList();

  List<Tour> _passiveTours(List<Tour> tours) =>
      tours.where((t) => t.status == TourStatus.idle).toList();

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
    return StreamBuilder<List<Tour>>(
      stream: _tourService.streamTours(),
      builder: (context, snapshot) {
        final loadedTours = snapshot.data ?? const <Tour>[];
        final tours = <Tour>[_mockTour, ...loadedTours];
        debugPrint('📊 Tours loaded from database: ${tours.length}');
        final activeTours = _activeTours(tours);
        final passiveTours = _passiveTours(tours);
        debugPrint('   - Active tours: ${activeTours.length}');
        debugPrint('   - Idle tours: ${passiveTours.length}');

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
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF1B5E20),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Builder(
                builder: (context) {
                  return ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      if (snapshot.hasError)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Database loading issue. Showing local mock tour.',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      if (activeTours.isNotEmpty) ...[
                        const _SectionHeader(title: 'Active Tours'),
                        const SizedBox(height: 10),
                        for (int i = 0; i < activeTours.length; i++) ...[
                          TourCard(
                            tour: activeTours[i],
                            onCardTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TourDetailScreen(tour: activeTours[i]),
                                ),
                              );
                            },
                          ),
                          if (i < activeTours.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 24),
                      ],
                      if (passiveTours.isNotEmpty) ...[
                        const _SectionHeader(title: 'Upcoming Tours'),
                        const SizedBox(height: 10),
                        for (int i = 0; i < passiveTours.length; i++) ...[
                          TourCard(
                            tour: passiveTours[i],
                            onCardTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TourDetailScreen(tour: passiveTours[i]),
                                ),
                              );
                            },
                          ),
                          if (i < passiveTours.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                      const SizedBox(height: 24),
                      if (loadedTours.isNotEmpty) ...[
                        const _SectionHeader(title: '🐛 Debug Info'),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loaded Tours: ${loadedTours.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final tour in loadedTours)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tour.name,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Total: ${tour.totalSeats} | Remaining: ${tour.remainingSeats} | Status: ${tour.status.name}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
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
