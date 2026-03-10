import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/widgets/tour_card.dart';

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
    ),
    Tour(
      name: 'Ella Nine Arches Bridge',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Nine_Arch_Bridge%2C_Ella%2C_Sri_Lanka.jpg/800px-Nine_Arch_Bridge%2C_Ella%2C_Sri_Lanka.jpg',
      startDate: DateTime(2026, 3, 18, 6, 0),
      totalSeats: 8,
      remainingSeats: 3,
    ),
    Tour(
      name: 'Galle Fort Heritage Walk',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Galle_Fort_-_Sri_Lanka.jpg/800px-Galle_Fort_-_Sri_Lanka.jpg',
      startDate: DateTime(2026, 3, 20, 8, 0),
      totalSeats: 10,
      remainingSeats: 0,
    ),
    Tour(
      name: 'Kandy Temple of the Tooth',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Temple_of_the_Tooth%2C_Kandy.jpg/800px-Temple_of_the_Tooth%2C_Kandy.jpg',
      startDate: DateTime(2026, 3, 22, 9, 0),
      totalSeats: 15,
      remainingSeats: 7,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
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
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
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
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
          ),
          // Glass search bar
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
          // Tour cards list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _tours.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return TourCard(tour: _tours[index]);
              },
            ),
          ),
        ],
      ),
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
                  _buildNavItem(Icons.explore_rounded, 'Explore', 1),
                  _buildNavItem(Icons.bookmark_rounded, 'Saved', 2),
                  _buildNavItem(Icons.person_rounded, 'Profile', 3),
                ],
              ),
            ),
          ),
        ),
      ),
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
