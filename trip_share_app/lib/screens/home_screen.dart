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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final TourService _tourService = TourService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Bookings load automatically when user authenticates
    // This ensures they load even if auth was cached
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) JoinedTourService().loadBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Idle tours: no one has booked yet (remainingSeats == totalSeats)
  List<Tour> _idleTours(List<Tour> tours) =>
      tours.where((t) => t.remainingSeats == t.totalSeats).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

  // Active tours: someone has already booked (remainingSeats < totalSeats)
  List<Tour> _activeTours(List<Tour> tours) =>
      tours.where((t) => t.remainingSeats < t.totalSeats).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

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
        if (snapshot.hasError) {
          debugPrint('🔴 StreamBuilder error: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.active) {
          debugPrint(
            '✅ StreamBuilder: active with ${(snapshot.data ?? []).length} tours',
          );
        }

        final loadedTours = snapshot.data ?? const <Tour>[];
        final tours = <Tour>[...loadedTours];
        final idleTours = _idleTours(tours);
        final activeTours = _activeTours(tours);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1B5E20),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(child: Text('Idle Tours')),
                    Tab(child: Text('Active Tours')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildToursView(context, snapshot, idleTours, true),
                  _buildToursView(context, snapshot, activeTours, false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToursView(
    BuildContext context,
    AsyncSnapshot<List<Tour>> snapshot,
    List<Tour> tours,
    bool isIdle,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Failed to load tours',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
      );
    }

    if (tours.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIdle ? Icons.new_label : Icons.trending_up,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              isIdle ? 'No idle tours available' : 'No active tours yet',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isIdle
                  ? 'Check back soon for new tours'
                  : 'Be the first to join a tour!',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: tours.length,
      itemBuilder: (context, index) {
        final tour = tours[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TourCard(tour: tour, isIdle: isIdle),
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
