class AppRoutes {
  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  
  // Main Routes
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';
  
  // Attendance Routes
  static const String attendance = '/attendance';
  static const String markAttendance = '/mark-attendance';
  static const String attendanceHistory = '/attendance-history';
  static const String scanQR = '/scan-qr';
  
  // Mess Routes
  static const String messToken = '/mess-token';
  static const String mealHistory = '/meal-history';
  static const String messMenu = '/mess-menu';
  static const String scanMess = '/scan-mess';
  
  // Complaint Routes
  static const String complaints = '/complaints';
  static const String raiseComplaint = '/raise-complaint';
  static const String complaintDetail = '/complaint-detail';
  static const String assignComplaint = '/assign-complaint';
  
  // Student Routes
  static const String students = '/students';
  static const String studentDetail = '/student-detail';
  static const String addStudent = '/add-student';
  static const String editStudent = '/edit-student';
  
  // Room Routes
    static const String rooms = '/rooms';
    static const String addRoom = '/add-room';
    static const String editRoom = '/edit-room';
    static const String roomDetail = '/room-detail';
    static const String allocateRoom = '/allocate-room';
    static const String myRoom = '/my-room';
  
  // // Fee Routes
  // static const String fees = '/fees';
  // static const String feePayment = '/fee-payment';
  // static const String feeHistory = '/fee-history';
  // static const String generateInvoice = '/generate-invoice';
  // static const String studentFeeStructure = '/student-fee-structure';

  // Fee Routes
static const String fees = '/fees';
static const String feeDashboard = '/fee-dashboard';  // Add this for admin
static const String feePayment = '/fee-payment';
static const String feeHistory = '/fee-history';
static const String generateInvoice = '/generate-invoice';
static const String studentFeeStructure = '/student-fee-structure';  // Student view
static const String feeRequests = '/fee-requests';

  
  // Chatbot
  static const String chatbot = '/chatbot';
  
  // Notifications
  static const String notifications = '/notifications';
  
  // Announcements
  static const String announcements = '/announcements';
  static const String announcementDetail = '/announcement-detail';
  
  // Reports
  //static const String reports = '/reports';
  
  // Settings
  static const String settings = '/settings';
  static const String hostelSettings = '/hostel-settings';
  static const String userManagement = '/user-management';
  static const String messManagement = '/mess-management';
  static const String messMenuManagement = '/mess-menu-management';
  static const String mealSubscription = '/meal-subscription';
  static const String consumptionReports = '/consumption-reports';

  static const String reportGenerator = '/report-generator';
}