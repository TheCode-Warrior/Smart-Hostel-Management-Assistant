import 'package:flutter/material.dart';
import 'package:fyp_2026/screens/fees/admin_fee_requests_screen.dart';
import 'package:fyp_2026/screens/fees/fee_dashboard_screen.dart';
import 'package:fyp_2026/screens/fees/fee_history_screen.dart';
import 'package:fyp_2026/screens/fees/fee_payment_screen.dart';
import 'package:fyp_2026/screens/rooms/add_room_screen.dart';
import 'package:fyp_2026/screens/rooms/edit_room_screen.dart';
import 'package:fyp_2026/screens/rooms/student_room_screen.dart';
import 'app_routes.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/home/profile_screen.dart';
import '../screens/attendance/attendance_screen.dart';
import '../screens/attendance/mark_attendance_screen.dart';
import '../screens/attendance/attendance_history_screen.dart';
import '../screens/attendance/scan_qr_screen.dart';
import '../screens/mess/mess_token_screen.dart';
import '../screens/mess/meal_history_screen.dart';
import '../screens/mess/mess_menu_screen.dart';
import '../screens/mess/scan_mess_screen.dart';
import '../screens/complaints/complaint_list_screen.dart';
import '../screens/complaints/raise_complaint_screen.dart';
import '../screens/complaints/complaint_detail_screen.dart';
import '../screens/complaints/assign_complaint_screen.dart';
import '../screens/students/student_list_screen.dart';
import '../screens/students/student_detail_screen.dart';
import '../screens/students/add_student_screen.dart';
import '../screens/students/edit_student_screen.dart';
import '../screens/rooms/room_list_screen.dart';
import '../screens/rooms/room_detail_screen.dart';
import '../screens/rooms/allocate_room_screen.dart';
import '../screens/fees/student_fee_structure_screen.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/notifications/notification_list_screen.dart';
import '../screens/announcements/announcement_list_screen.dart';
import '../screens/announcements/announcement_detail_screen.dart';
import '../screens/reports/report_generator_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/hostel_settings_screen.dart';
import '../screens/settings/user_management_screen.dart';
import '../screens/settings/mess_management_screen.dart';
import '../screens/settings/mess_menu_management_screen.dart';
import '../screens/mess/meal_subscription_screen.dart';
import '../screens/admin/consumption_report_screen.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      // Auth Routes
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) =>  LoginScreen());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      
      // Main Routes
      case AppRoutes.home:
      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) =>  DashboardScreen());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      // Attendance Routes
      case AppRoutes.attendance:
        return MaterialPageRoute(builder: (_) => const AttendanceScreen());
      case AppRoutes.markAttendance:
        return MaterialPageRoute(builder: (_) => const MarkAttendanceScreen());
      case AppRoutes.attendanceHistory:
        return MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen());
      case AppRoutes.scanQR:
        return MaterialPageRoute(builder: (_) => const ScanQRScreen());
      
      // Mess Routes
      case AppRoutes.messToken:
        return MaterialPageRoute(builder: (_) =>  MessTokenScreen());
      case AppRoutes.mealHistory:
        return MaterialPageRoute(builder: (_) => const MealHistoryScreen());
      case AppRoutes.messMenu:
        return MaterialPageRoute(builder: (_) => const MessMenuScreen());
      case AppRoutes.scanMess:
        return MaterialPageRoute(builder: (_) => const ScanMessScreen());
      
      // Complaint Routes
      case AppRoutes.complaints:
        return MaterialPageRoute(builder: (_) => const ComplaintListScreen());
      case AppRoutes.raiseComplaint:
        return MaterialPageRoute(builder: (_) =>  RaiseComplaintScreen());
      case AppRoutes.complaintDetail:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaintId: args),
          );
        }
        return _errorRoute();
      case AppRoutes.assignComplaint:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => AssignComplaintScreen(complaintId: args),
          );
        }
        return _errorRoute();
      
      // Student Routes
      case AppRoutes.students:
        return MaterialPageRoute(builder: (_) => const StudentListScreen());
      case AppRoutes.studentDetail:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => StudentDetailScreen(studentId: args),
          );
        }
        return _errorRoute();
      case AppRoutes.addStudent:
        return MaterialPageRoute(builder: (_) => const AddStudentScreen());
      case AppRoutes.editStudent:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => EditStudentScreen(studentId: args),
          );
        }
        return _errorRoute();
      
     // Room ROutes

case AppRoutes.rooms:
  return MaterialPageRoute(builder: (_) => const RoomListScreen());
case AppRoutes.addRoom:
  return MaterialPageRoute(builder: (_) => const AddRoomScreen());
case AppRoutes.editRoom:
  if (args is String) {
    return MaterialPageRoute(
      builder: (_) => EditRoomScreen(roomId: args),
    );
  }
  return _errorRoute();
case AppRoutes.roomDetail:
  if (args is String) {
    return MaterialPageRoute(
      builder: (_) => RoomDetailScreen(roomId: args),
    );
  }
  return _errorRoute();

case AppRoutes.allocateRoom:
  if (args is Map<String, dynamic>) {
    return MaterialPageRoute(
      builder: (_) => AllocateRoomScreen(
        roomId: args['roomId'],
        studentId: args['studentId'],
      ),
    );
  }
  return MaterialPageRoute(
    builder: (_) => const AllocateRoomScreen(roomId: null, studentId: null),
  );
  case AppRoutes.myRoom:
  return MaterialPageRoute(builder: (_) => const StudentRoomScreen());
      
      
      // Fee Routes
case AppRoutes.fees:
case AppRoutes.feePayment:
  return MaterialPageRoute(builder: (_) => const FeePaymentScreen());
case AppRoutes.studentFeeStructure:
  return MaterialPageRoute(builder: (_) => const StudentFeeStructureScreen());
case AppRoutes.feeRequests:
  return MaterialPageRoute(builder: (_) => const AdminFeeRequestsScreen());

case AppRoutes.feeDashboard:
  return MaterialPageRoute(builder: (_) => const FeeDashboardScreen());

    case AppRoutes.feeHistory:
  return MaterialPageRoute(builder: (_) => const FeeHistoryScreen());

      // Chatbot
      case AppRoutes.chatbot:
  return MaterialPageRoute(builder: (_) => ChatbotScreen());
      
      // Notifications
      case AppRoutes.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationListScreen());
      
      // Announcements
      case AppRoutes.announcements:
        return MaterialPageRoute(builder: (_) => const AnnouncementListScreen());
      case AppRoutes.announcementDetail:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => AnnouncementDetailScreen(announcementId: args),
          );
        }
        return _errorRoute();
      
      // Reports
      case AppRoutes.reportGenerator:
        return MaterialPageRoute(builder: (_) => const ReportGeneratorScreen());
      
      // Settings
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.hostelSettings:
        return MaterialPageRoute(builder: (_) => const HostelSettingsScreen());
      case AppRoutes.userManagement:
        return MaterialPageRoute(builder: (_) => const UserManagementScreen());
      case AppRoutes.messManagement:
        return MaterialPageRoute(builder: (_) => const MessManagementScreen());
      case AppRoutes.messMenuManagement:
        return MaterialPageRoute(builder: (_) => const MessMenuManagementScreen());
      case AppRoutes.mealSubscription:
        return MaterialPageRoute(builder: (_) => const MealSubscriptionScreen());
      case AppRoutes.consumptionReports:
        return MaterialPageRoute(builder: (_) => const ConsumptionReportScreen());
      
      
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Route not found'),
        ),
      ),
    );
  }

  
}