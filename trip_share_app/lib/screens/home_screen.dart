import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/tour_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/widgets/tour_card.dart';
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
  final JoinedTourService _joinedTourService = JoinedTourService();

  late final Stream<List<Tour>> _toursStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _toursStream = _tourService.streamTours();
    _joinedTourService.addListener(_onBookingUpdate);
    // Bookings load automatically when user authenticates
    // This ensures they load even if auth was cached
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _joinedTourService.loadBookings();
    });
  }

  @override
  void dispose() {
    _joinedTourService.removeListener(_onBookingUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _onBookingUpdate() {
    if (mounted) setState(() {});
  }

  // Idle tours: no one has booked yet (remainingSeats == totalSeats)
  List<Tour> _idleTours(List<Tour> tours) {
    final activeTourIds = _joinedTourService.joinedTours
        .map((jt) => jt.tour.id)
        .toSet();
    final idle =
        tours
            .where(
              (t) =>
                  t.remainingSeats == t.totalSeats &&
                  !activeTourIds.contains(t.id),
            )
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    debugPrint('✅ IDLE TOURS (${idle.length})');
    return idle;
  }

  // Active tours: someone has already booked (remainingSeats < totalSeats)
  List<Tour> _activeTours(List<Tour> tours) {
    final activeTourIds = _joinedTourService.joinedTours
        .map((jt) => jt.tour.id)
        .toSet();
    final active =
        tours
            .where(
              (t) =>
                  t.remainingSeats < t.totalSeats ||
                  activeTourIds.contains(t.id),
            )
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
    debugPrint('✅ ACTIVE TOURS (${active.length})');
    return active;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _selectedIndex == 0
          ? const Color(0xFF070B17)
          : const Color(0xFFF4F4F7),
      body: _buildBody(),
      appBar: _selectedIndex == 0
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                _selectedIndex == 1
                    ? 'Chats'
                    : _selectedIndex == 2
                    ? 'Joined Tours'
                    : 'Profile',
                style: const TextStyle(
                  color: Color(0xFF0B1220),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  fontSize: 19,
                ),
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: _selectedIndex == 0
                ? const Color(0xFF0F1627)
                : const Color(0xFF121A2E),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 10),
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
      stream: _toursStream,
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

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111B33), Color(0xFF070B17), Color(0xFF04060D)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: SizedBox(
                    height: 186,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset('assets/bg.jpg', fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.68),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: -36,
                            right: -22,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 16,
                            right: 16,
                            bottom: 42,
                            child: Text(
                              'Find your favorite place\nand travel with us',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 21,
                                height: 1.25,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 14,
                            child: Row(
                              children: [
                                _buildHeroBadge(
                                  icon: Icons.auto_awesome,
                                  label: 'Premium Tours',
                                ),
                                const SizedBox(width: 8),
                                _buildHeroBadge(
                                  icon: Icons.shield_moon,
                                  label: 'Trusted Drivers',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'London, Bangkok etc',
                        hintStyle: TextStyle(color: Color(0xFF9FA9C2)),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Color(0xFFFF5B8A),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        splashBorderRadius: BorderRadius.circular(12),
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3BA5FF), Color(0xFF1E6DE2)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3BA5FF,
                              ).withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF9FA9C2),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        tabs: [
                          Tab(text: 'Idle Tours (${idleTours.length})'),
                          Tab(text: 'Active Tours (${activeTours.length})'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildToursView(context, snapshot, idleTours),
                      _buildToursView(context, snapshot, activeTours),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToursView(
    BuildContext context,
    AsyncSnapshot<List<Tour>> snapshot,
    List<Tour> tours,
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
        child: CircularProgressIndicator(color: Color(0xFF1E6DE2)),
      );
    }

    if (tours.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: 64,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            const Text(
              'No tours available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check back soon for new adventures!',
              style: TextStyle(fontSize: 13, color: Color(0xFF9FA9C2)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: tours.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 0,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final tour = tours[index];
        return TourCard(
          key: ValueKey('${tour.id}-${tour.remainingSeats}'),
          tour: tour,
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFFF5B8A)
                  : const Color(0xFFAFB6C8),
              size: 23,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFAFB6C8),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
