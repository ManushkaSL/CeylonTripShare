import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/tour_service.dart';
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
  final TourService _tourService = TourService();

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
        final tours = snapshot.data ?? const <Tour>[];
        final activeTours = _activeTours(tours);
        final passiveTours = _passiveTours(tours);

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
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Failed to load tours',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (tours.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tours available right now',
                        style: TextStyle(color: Color(0xFF666666)),
                      ),
                    );
                  }

                  return ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      if (activeTours.isNotEmpty) ...[
                        const _SectionHeader(title: 'Active Tours'),
                        const SizedBox(height: 10),
                        for (int i = 0; i < activeTours.length; i++) ...[
                          TourCard(tour: activeTours[i]),
                          if (i < activeTours.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 24),
                      ],
                      if (passiveTours.isNotEmpty) ...[
                        const _SectionHeader(title: 'Upcoming Tours'),
                        const SizedBox(height: 10),
                        for (int i = 0; i < passiveTours.length; i++) ...[
                          TourCard(tour: passiveTours[i]),
                          if (i < passiveTours.length - 1)
                            const SizedBox(height: 12),
                        ],
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
