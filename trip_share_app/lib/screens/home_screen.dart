import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/tour_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
import 'package:trip_share_app/widgets/skeleton_loader.dart';
import 'package:trip_share_app/theme/design_system.dart';
import 'package:trip_share_app/screens/joined_tours_screen.dart';
import 'package:trip_share_app/screens/chats_list_screen.dart';
import 'package:trip_share_app/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _selectedTabIndex = 0; // 0 = Active Tours, 1 = Idle Tours
  final TourService _tourService = TourService();
  final JoinedTourService _joinedTourService = JoinedTourService();
  final _auth = AuthService();
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Safari',
    'Beach',
    'Camping',
    'Hiking / Trekking',
    'Cultural / City tours',
    'Adventure',
  ];

  final Map<String, IconData> _categoryIcons = {
    'All': Icons.grid_view_rounded,
    'Safari': Icons.local_florist_rounded,
    'Beach': Icons.beach_access_rounded,
    'Camping': Icons.cabin_rounded,
    'Hiking / Trekking': Icons.terrain_rounded,
    'Cultural / City tours': Icons.location_city_rounded,
    'Adventure': Icons.terrain,
  };

  late final Stream<List<Tour>> _toursStream;
  final ScrollController _scrollController = ScrollController();
  Timer? _greetingTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // --- Filters state
  String _filterCategory = 'All';
  String? _filterLocation; // single selection for simplicity
  String? _filterDuration; // 'half-day','full-day','2-3 days','custom'
  String _filterPriceBucket =
      'Any'; // 'Any','Budget','Under50','50-200','Premium'
  String _filterAvailability =
      'Any'; // 'Any','Available','Limited','FullyBooked'
  double _filterMinRating = 0.0;

  @override
  void initState() {
    super.initState();
    _toursStream = _tourService.streamTours();
    _joinedTourService.addListener(_onBookingUpdate);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _joinedTourService.loadBookings();
    });
    _scheduleGreetingRefresh();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
        });
      }
    });
  }

  @override
  void dispose() {
    _joinedTourService.removeListener(_onBookingUpdate);
    _scrollController.dispose();
    _greetingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onBookingUpdate() {
    if (mounted) setState(() {});
  }

  List<Tour> _filterTours(List<Tour> tours) {
    if (_selectedCategory == 'All') return tours;
    return tours.where((t) => t.category == _selectedCategory).toList();
  }

  List<Tour> _idleTours(List<Tour> tours) {
    final activeTourIds = _joinedTourService.joinedTours
        .map((jt) => jt.tour.id)
        .toSet();

    return tours
        .where(
          (t) => t.status == TourStatus.idle && !activeTourIds.contains(t.id),
        )
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<Tour> _activeTours(List<Tour> tours) {
    final activeTourIds = _joinedTourService.joinedTours
        .map((jt) => jt.tour.id)
        .toSet();

    return tours
        .where(
          (t) => t.status != TourStatus.idle || activeTourIds.contains(t.id),
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning,';
    if (hour >= 12 && hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  void _scheduleGreetingRefresh() {
    _greetingTimer?.cancel();
    final now = DateTime.now();
    // Next thresholds: 05:00, 12:00, 17:00, 21:00 (then next day 05:00)
    final thresholds = [5, 12, 17, 21];
    int? nextHour;
    for (final t in thresholds) {
      if (now.hour < t) {
        nextHour = t;
        break;
      }
    }
    nextHour ??= 5 + 24; // next day's 5
    final next = DateTime(now.year, now.month, now.day, nextHour).isAfter(now)
        ? DateTime(now.year, now.month, now.day, nextHour)
        : DateTime(now.year, now.month, now.day + 1, nextHour % 24);
    final duration = next.difference(now) + const Duration(seconds: 1);
    _greetingTimer = Timer(duration, () {
      if (mounted) setState(() {});
      _scheduleGreetingRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: DesignColors.background,
      body: _selectedIndex == 0 ? _buildHomeContent() : _buildBody(),
      appBar: _selectedIndex == 0
          ? null
          : AppBar(
              backgroundColor: DesignColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                _selectedIndex == 1
                    ? 'Chats'
                    : _selectedIndex == 2
                    ? 'Joined Tours'
                    : 'Profile',
                style: TextStyle(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontSize: 20,
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavBar(),
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
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeroIconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 20)),
    );
  }

  // ─── SEARCH & FILTER BAR ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C2219).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: DesignColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search premium tours...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: DesignColors.textSecondary.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: DesignColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DesignColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Luxury equalizer filter button (clickable)
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DesignColors.primaryLight, DesignColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hero banner shown at the top of Home
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        image: const DecorationImage(
          image: AssetImage('assets/bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.55),
              Colors.black.withOpacity(0.2),
              Colors.black.withOpacity(0.75),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DesignColors.accent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        gradient: const LinearGradient(
                          colors: [
                            DesignColors.primaryLight,
                            DesignColors.primary,
                          ],
                        ),
                      ),
                      child: const ClipOval(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _auth.userName.isNotEmpty
                                    ? _auth.userName
                                    : 'Guest',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '👋',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: DesignColors.accent.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildHeroIconButton(Icons.notifications_outlined),
                    const SizedBox(width: 10),
                    _buildHeroIconButton(Icons.favorite_border_rounded),
                  ],
                ),
                const Spacer(),
                Text(
                  "EXPLORE SRI LANKA'S",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: DesignColors.accent,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The Great Wild Safari',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Immerse in breathtaking encounters with majestic wildlife.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PREMIUM CATEGORY CHIPS ────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 46,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          primary: false,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category;
            final icon = _categoryIcons[category] ?? Icons.category;

            return Padding(
              padding: EdgeInsets.only(
                right: index == _categories.length - 1 ? 0 : 10,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                    _filterCategory = category;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [
                              DesignColors.primary,
                              DesignColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : DesignColors.divider,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: DesignColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? DesignColors.accent
                            : DesignColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : DesignColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Tour> _applyFilters(List<Tour> tours) {
    var results = tours;

    // Activity / Category
    if (_filterCategory.isNotEmpty && _filterCategory != 'All') {
      results = results
          .where(
            (t) =>
                (t.category ?? '').toLowerCase() ==
                _filterCategory.toLowerCase(),
          )
          .toList();
    }

    // Location
    if (_filterLocation != null && _filterLocation!.isNotEmpty) {
      results = results
          .where(
            (t) => (t.startLocation ?? '').toLowerCase().contains(
              _filterLocation!.toLowerCase(),
            ),
          )
          .toList();
    }

    // Duration - check tourFeatures tags (if present)
    if (_filterDuration != null && _filterDuration!.isNotEmpty) {
      final key = _filterDuration!.toLowerCase();
      results = results
          .where(
            (t) => t.tourFeatures.any((f) => f.toLowerCase().contains(key)),
          )
          .toList();
    }

    // Price buckets
    if (_filterPriceBucket != 'Any') {
      results = results.where((t) {
        final p = t.price;
        switch (_filterPriceBucket) {
          case 'Budget':
            return p <= 0 || p < 20;
          case 'Under50':
            return p > 0 && p < 50;
          case '50-200':
            return p >= 50 && p <= 200;
          case 'Premium':
            return p > 200;
          default:
            return true;
        }
      }).toList();
    }

    // Availability
    if (_filterAvailability != 'Any') {
      results = results.where((t) {
        if (_filterAvailability == 'Available') return t.remainingSeats > 2;
        if (_filterAvailability == 'Limited')
          return t.remainingSeats > 0 && t.remainingSeats <= 2;
        if (_filterAvailability == 'FullyBooked') return t.remainingSeats == 0;
        return true;
      }).toList();
    }

    // Rating
    if (_filterMinRating > 0) {
      results = results.where((t) => (t.rating >= _filterMinRating)).toList();
    }

    // Search query (name, location, category)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      results = results.where((t) {
        final name = (t.name ?? '').toLowerCase();
        final loc = (t.startLocation ?? '').toLowerCase();
        final cat = (t.category ?? '').toLowerCase();
        return name.contains(q) || loc.contains(q) || cat.contains(q);
      }).toList();
    }

    return results;
  }

  Widget _buildFilterBar() {
    final activeFilters = <String>[];
    if (_filterCategory != 'All') activeFilters.add('Activity');
    if (_filterLocation != null) activeFilters.add('Location');
    if (_filterDuration != null) activeFilters.add('Duration');
    if (_filterPriceBucket != 'Any') activeFilters.add('Price');
    if (_filterAvailability != 'Any') activeFilters.add('Availability');
    if (_filterMinRating > 0) activeFilters.add('Rating');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showFilterSheet,
              icon: const Icon(Icons.filter_list),
              label: Text(
                activeFilters.isEmpty
                    ? 'Filters'
                    : 'Filters (${activeFilters.length})',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignColors.textPrimary,
                side: BorderSide(color: DesignColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              setState(() {
                // reset filters
                _filterCategory = 'All';
                _selectedCategory = 'All';
                _filterLocation = null;
                _filterDuration = null;
                _filterPriceBucket = 'Any';
                _filterAvailability = 'Any';
                _filterMinRating = 0.0;
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // local copies to edit
        String localCategory = _filterCategory;
        String localLocation = _filterLocation ?? '';
        String localDuration = _filterDuration ?? '';
        String localPrice = _filterPriceBucket;
        String localAvailability = _filterAvailability;
        double localRating = _filterMinRating;

        Widget _chip(
          String label, {
          IconData? icon,
          required bool selected,
          required VoidCallback onTap,
          String? smallLabel,
        }) {
          return GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(right: 8, bottom: 8),
              decoration: BoxDecoration(
                color: selected ? DesignColors.primary : DesignColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignColors.divider),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: DesignColors.primary.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: selected
                          ? Colors.white
                          : DesignColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : DesignColors.textPrimary,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setLocal) {
                return Container(
                  decoration: BoxDecoration(
                    color: DesignColors.background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: DesignColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.textPrimary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // reset local
                                setLocal(() {
                                  localCategory = 'All';
                                  localLocation = '';
                                  localDuration = '';
                                  localPrice = 'Any';
                                  localAvailability = 'Any';
                                  localRating = 0.0;
                                });
                              },
                              icon: Icon(
                                Icons.refresh,
                                size: 18,
                                color: DesignColors.textSecondary,
                              ),
                              label: Text(
                                'Reset all',
                                style: TextStyle(
                                  color: DesignColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Activity / Type
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DesignColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.filter_alt,
                                      color: DesignColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Activity / Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                children: _categories.map((c) {
                                  final icon =
                                      _categoryIcons[c] ?? Icons.category;
                                  final sel = localCategory == c;
                                  return _chip(
                                    c,
                                    icon: icon,
                                    selected: sel,
                                    onTap: () {
                                      setLocal(() {
                                        localCategory = sel ? 'All' : c;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),

                              // Location
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DesignColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: DesignColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                children:
                                    [
                                          'Ella',
                                          'Yala',
                                          'Udawalawe',
                                          'Mirissa',
                                          'Kandy',
                                        ]
                                        .map(
                                          (loc) => _chip(
                                            loc,
                                            selected: localLocation == loc,
                                            onTap: () {
                                              setLocal(() {
                                                localLocation =
                                                    localLocation == loc
                                                    ? ''
                                                    : loc;
                                              });
                                            },
                                          ),
                                        )
                                        .toList(),
                              ),
                              const SizedBox(height: 18),

                              // Duration
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DesignColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.schedule,
                                      color: DesignColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Duration',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                children:
                                    [
                                          'Half-day',
                                          'Full-day',
                                          '2-3 days',
                                          'Custom',
                                        ]
                                        .map(
                                          (d) => _chip(
                                            d,
                                            selected: localDuration == d,
                                            onTap: () {
                                              setLocal(() {
                                                localDuration =
                                                    localDuration == d ? '' : d;
                                              });
                                            },
                                          ),
                                        )
                                        .toList(),
                              ),
                              const SizedBox(height: 18),

                              // Price
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DesignColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.attach_money,
                                      color: DesignColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Price',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                children:
                                    [
                                      'Any',
                                      'Budget',
                                      'Under50',
                                      '50-200',
                                      'Premium',
                                    ].map((p) {
                                      final label = p == 'Under50'
                                          ? 'Under \$50'
                                          : p == '50-200'
                                          ? '\$50-\$200'
                                          : p == 'Any'
                                          ? 'Any'
                                          : p;
                                      return _chip(
                                        label,
                                        selected: localPrice == p,
                                        onTap: () {
                                          setLocal(() {
                                            localPrice = localPrice == p
                                                ? 'Any'
                                                : p;
                                          });
                                        },
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 18),

                              // Availability
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DesignColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: DesignColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Availability',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                children:
                                    [
                                      'Any',
                                      'Available',
                                      'Limited',
                                      'FullyBooked',
                                    ].map((a) {
                                      Widget statusDot(String key) {
                                        if (key == 'Available')
                                          return Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.green,
                                            ),
                                          );
                                        if (key == 'Limited')
                                          return Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.orange,
                                            ),
                                          );
                                        if (key == 'FullyBooked')
                                          return Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.red,
                                            ),
                                          );
                                        return const SizedBox.shrink();
                                      }

                                      final label = a == 'FullyBooked'
                                          ? 'Fully booked'
                                          : a;
                                      final sel = localAvailability == a;
                                      return GestureDetector(
                                        onTap: () {
                                          setLocal(() {
                                            localAvailability = sel ? 'Any' : a;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? DesignColors.primary
                                                : DesignColors.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: DesignColors.divider,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (a != 'Any') ...[
                                                statusDot(a),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  color: sel
                                                      ? Colors.white
                                                      : DesignColors
                                                            .textPrimary,
                                                ),
                                              ),
                                              if (sel) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.check_circle,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 18),

                              // Rating
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: DesignColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: DesignColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Minimum Rating',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Slider(
                                value: localRating,
                                onChanged: (v) {
                                  setLocal(() {
                                    localRating = v;
                                  });
                                },
                                min: 0,
                                max: 5,
                                divisions: 5,
                                label: localRating == 0
                                    ? 'Any'
                                    : localRating.toStringAsFixed(1),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // Bottom actions
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _filterCategory = localCategory.isEmpty
                                        ? 'All'
                                        : localCategory;
                                    _selectedCategory = _filterCategory;
                                    _filterLocation = localLocation.isEmpty
                                        ? null
                                        : localLocation;
                                    _filterDuration = localDuration.isEmpty
                                        ? null
                                        : localDuration;
                                    _filterPriceBucket = localPrice;
                                    _filterAvailability = localAvailability;
                                    _filterMinRating = localRating;
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: const Text('OK'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: DesignColors.divider),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: DesignColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── LUXURIOUS TAB SWITCHER (CAPSULE INDICATOR) ───────────────────
  Widget _buildTabSelector(int activeCount, int idleCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF0EAE3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.divider, width: 1.2),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTabIndex = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: _selectedTabIndex == 0
                        ? const LinearGradient(
                            colors: [
                              DesignColors.primary,
                              DesignColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    boxShadow: _selectedTabIndex == 0
                        ? [
                            BoxShadow(
                              color: DesignColors.primary.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      'Active Tours ($activeCount)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _selectedTabIndex == 0
                            ? Colors.white
                            : DesignColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTabIndex = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: _selectedTabIndex == 1
                        ? const LinearGradient(
                            colors: [
                              DesignColors.primary,
                              DesignColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    boxShadow: _selectedTabIndex == 1
                        ? [
                            BoxShadow(
                              color: DesignColors.primary.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      'Idle Tours ($idleCount)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _selectedTabIndex == 1
                            ? Colors.white
                            : DesignColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOUR SECTION HEADER ──────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: DesignColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          GestureDetector(
            child: Row(
              children: [
                Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: DesignColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PREMIUM CUSTOM TOUR CARD ──────────────────────────────────────
  Widget _buildTourCard(BuildContext context, Tour tour) {
    final rating = tour.rating;
    final bookedSeats = tour.totalSeats - tour.remainingSeats;
    final fillRatio = tour.totalSeats > 0 ? bookedSeats / tour.totalSeats : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 152,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: DesignColors.divider.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C2219).withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left block: Rounded tour image + dynamic floating actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 120,
                      height: 128,
                      child: CachedNetworkImage(
                        imageUrl: tour.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEFEFEF), Color(0xFFE5E5E5)],
                            ),
                          ),
                        ),
                        errorWidget: (c, u, e) => Container(
                          color: DesignColors.divider,
                          child: Icon(
                            Icons.landscape_rounded,
                            color: DesignColors.textSecondary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Luxurious glassmorphic rating badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: DesignColors.accent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Glassmorphic interactive favorite heart circle
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 16,
                        color: DesignColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right block: Premium Metadata and actions
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tour name with premium bold font style
                    Text(
                      tour.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Refined Location layout
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: DesignColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tour.startLocation,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: DesignColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Custom seats capacity indicator line
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  size: 13,
                                  color: DesignColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$bookedSeats/${tour.totalSeats} seats booked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: DesignColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${tour.remainingSeats} left',
                              style: TextStyle(
                                fontSize: 11,
                                color: tour.remainingSeats <= 2
                                    ? DesignColors.accentSecondary
                                    : DesignColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Sleek custom linear loading meter
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 4,
                            width: double.infinity,
                            color: DesignColors.divider,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fillRatio,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      DesignColors.primaryLight,
                                      DesignColors.primary,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Price + dynamic View Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '\$${tour.price.toInt()}',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: DesignColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: ' / person',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: DesignColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Custom styled detail button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                DesignColors.primary,
                                DesignColors.primaryDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: DesignColors.primary.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CUSTOM SKELETON LOADER ────────────────────────────────────────
  Widget _buildSkeletonCards() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            height: 152,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: DesignColors.divider, width: 1),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SkeletonLoader(height: 128, width: 120),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonLoader(height: 18, width: 150),
                        SizedBox(height: 12),
                        SkeletonLoader(height: 12),
                        SizedBox(height: 12),
                        SkeletonLoader(height: 12, width: 110),
                        SizedBox(height: 12),
                        SkeletonLoader(height: 16, width: 90),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── EXQUISITE EMPTY STATE ──────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.divider.withOpacity(0.5),
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 40,
                color: DesignColors.primaryLight.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tours found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Explore another category or check back later!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: DesignColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MAIN HOME CONTENT ──────────────────────────────────────────
  Widget _buildHomeContent() {
    return StreamBuilder<List<Tour>>(
      stream: _toursStream,
      builder: (context, snapshot) {
        final loadedTours = snapshot.data ?? const <Tour>[];
        final filteredTours = _applyFilters(loadedTours);
        final tours = <Tour>[...filteredTours];
        final idleTours = _idleTours(tours);
        final activeTours = _activeTours(tours);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              _buildHeroBanner(),
              const SizedBox(height: 18),

              // Search Bar
              _buildSearchBar(),
              const SizedBox(height: 18),

              // Category Chips
              _buildCategoryChips(),
              const SizedBox(height: 18),

              // Tab Selector
              _buildTabSelector(activeTours.length, idleTours.length),
              const SizedBox(height: 22),

              // SWITCHABLE VIEW: ONLY RENDER SELECTED TAB DATA
              if (_selectedTabIndex == 0) ...[
                _buildSectionHeader('Active Tours'),
                const SizedBox(height: 14),
                if (isLoading)
                  _buildSkeletonCards()
                else if (activeTours.isEmpty)
                  _buildEmptyState()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: activeTours
                          .map((tour) => _buildTourCard(context, tour))
                          .toList(),
                    ),
                  ),
              ] else ...[
                _buildSectionHeader('Idle Tours'),
                const SizedBox(height: 14),
                if (isLoading)
                  _buildSkeletonCards()
                else if (idleTours.isEmpty)
                  _buildEmptyState()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: idleTours
                          .map((tour) => _buildTourCard(context, tour))
                          .toList(),
                    ),
                  ),
              ],

              // Clean footer clearance padding
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ─── BOTTOM NAVIGATION BAR ────────────────────────────────────
  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DesignColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, Icons.home_outlined, 'Home', 0),
              _buildNavItem(
                Icons.chat_bubble_rounded,
                Icons.chat_bubble_outline_rounded,
                'Chats',
                1,
              ),
              _buildNavItem(
                Icons.luggage_rounded,
                Icons.luggage_outlined,
                'Joined',
                2,
              ),
              _buildNavItem(
                Icons.person_rounded,
                Icons.person_outline_rounded,
                'Profile',
                3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected
                  ? DesignColors.primary
                  : DesignColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? DesignColors.primary
                    : DesignColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
