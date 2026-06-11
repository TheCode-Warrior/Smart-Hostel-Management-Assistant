import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/room_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/room_model.dart';
import '../../routes/app_routes.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({Key? key}) : super(key: key);

  @override
  _RoomListScreenState createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  String _searchQuery = '';
  String _selectedBlock = 'All';
  String _selectedStatus = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _blocks = ['All', 'A', 'B', 'C', 'D'];
  final List<String> _statuses = ['All', 'Available', 'Occupied', 'Maintenance'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    await roomProvider.loadAllRooms();
  }

  List<RoomModel> _getFilteredRooms() {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    
    List<RoomModel> filtered = roomProvider.rooms;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) =>
        r.roomNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false
      ).toList();
    }
    
    // Apply block filter
    if (_selectedBlock != 'All') {
      filtered = filtered.where((r) => r.hostelBlock == _selectedBlock).toList();
    }
    
    // Apply status filter
    if (_selectedStatus != 'All') {
      filtered = filtered.where((r) {
        if (_selectedStatus == 'Available') return r.isAvailable == true;
        if (_selectedStatus == 'Occupied') return r.isAvailable == false && r.status != RoomStatus.maintenance;
        if (_selectedStatus == 'Maintenance') return r.status == RoomStatus.maintenance;
        return true;
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final canAddRoom = authProvider.user?.roleString == 'Admin' || 
                       authProvider.user?.roleString == 'Mess Staff';
    final filteredRooms = _getFilteredRooms();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by room number...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.grey600),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.grey600),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              
              // Block Filter Chips
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _blocks.length,
                  itemBuilder: (context, index) {
                    final block = _blocks[index];
                    final isSelected = _selectedBlock == block;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(block == 'All' ? 'All Blocks' : 'Block $block'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedBlock = selected ? block : 'All');
                        },
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.grey700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Status Filter Chips
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statuses.length,
                  itemBuilder: (context, index) {
                    final status = _statuses[index];
                    final isSelected = _selectedStatus == status;
                    final statusColor = _getStatusColor(status);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedStatus = selected ? status : 'All');
                        },
                        backgroundColor: Colors.white,
                        selectedColor: statusColor.withOpacity(0.2),
                        checkmarkColor: statusColor,
                        labelStyle: TextStyle(
                          color: isSelected ? statusColor : AppColors.grey700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () => _showStatsDialog(roomProvider.roomStats),
            tooltip: 'Statistics',
          ),
        ],
      ),
      body: roomProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: roomProvider.rooms.isEmpty
                  ? _buildEmptyState()
                  : filteredRooms.isEmpty
                      ? _buildNoResultsState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = filteredRooms[index];
                            return _buildRoomCard(room);
                          },
                        ),
            ),
      floatingActionButton: canAddRoom
    ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.addRoom).then((_) => _loadData());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
        backgroundColor: AppColors.primary,
      )
    : null,
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    final statusColor = room.isAvailable == true
        ? Colors.green
        : (room.status == RoomStatus.maintenance ? Colors.orange : Colors.red);
    final occupancyText = '${room.currentOccupancy}/${room.capacity}';
    final isFull = room.currentOccupancy == room.capacity;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.roomDetail,
          arguments: room.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with block and status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Block ${room.hostelBlock}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      room.statusString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Room details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${room.roomNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Floor ${room.floor}',
                    style: TextStyle(
                      color: AppColors.grey600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Occupancy
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: AppColors.grey500),
                      const SizedBox(width: 4),
                      Text(
                        occupancyText,
                        style: TextStyle(
                          color: isFull ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Room Type
                  Row(
                    children: [
                      Icon(Icons.bed, size: 14, color: AppColors.grey500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.roomTypeString,
                          style: TextStyle(
                            color: AppColors.grey700,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Rent
                  Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 14, color: AppColors.grey500),
                      const SizedBox(width: 4),
                      Text(
                        '₹${room.monthlyRent}/month',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No Rooms Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'There are no rooms added yet.\nTap the + button to add a new room.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No Matching Rooms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No rooms match your search criteria.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Room Statistics'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Rooms', '${stats['total'] ?? 0}'),
            const Divider(),
            _buildStatRow('Available', '${stats['available'] ?? 0}', color: Colors.green),
            _buildStatRow('Occupied', '${stats['occupied'] ?? 0}', color: Colors.red),
            _buildStatRow('Maintenance', '${stats['maintenance'] ?? 0}', color: Colors.orange),
            const Divider(),
            _buildStatRow('Total Capacity', '${stats['totalCapacity'] ?? 0}'),
            _buildStatRow('Current Occupancy', '${stats['totalOccupancy'] ?? 0}'),
            _buildStatRow(
              'Occupancy Rate',
              '${(stats['occupancyRate'] ?? 0).toStringAsFixed(1)}%',
              color: AppColors.primary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Occupied':
        return Colors.red;
      case 'Maintenance':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  
}