// import 'package:flutter/material.dart';
// import '../services/admin_api_service.dart';
// import '../models/admin_models.dart';
// import '../theme/app_colors.dart';

// class AdminInstitutionsScreen extends StatefulWidget {
//   const AdminInstitutionsScreen({super.key});

//   @override
//   State<AdminInstitutionsScreen> createState() => _AdminInstitutionsScreenState();
// }

// class _AdminInstitutionsScreenState extends State<AdminInstitutionsScreen> {
//   List<Institution> _institutions = [];
//   bool _isLoading = true;
//   String _errorMessage = '';
//   int _currentPage = 1;
//   int _totalPages = 1;
//   String _searchQuery = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadInstitutions();
//   }

//   Future<void> _loadInstitutions() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//       });

//       final response = await AdminApiService.getInstitutions(
//         page: _currentPage,
//         limit: 20,
//         search: _searchQuery.isNotEmpty ? _searchQuery : null,
//       );

//       if (response['success'] == true) {
//         final institutionsData = (response['data']?['institutions'] as List?) ?? [];
//         setState(() {
//           _institutions = institutionsData
//               .map((inst) => Institution.fromJson((inst as Map).cast<String, dynamic>()))
//               .toList();
//           _totalPages = response['data']?['totalPages'] ?? 1;
//           _isLoading = false;
//         });
//       } else {
//         throw Exception(response['message'] ?? 'Failed to load institutions');
//       }
//     } catch (e) {
//       print('❌ Error loading institutions: $e');
//       setState(() {
//         _errorMessage = 'Failed to load institutions: $e';
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _approveInstitution(int institutionId) async {
//     try {
//       final success = await AdminApiService.approveInstitution(institutionId);

//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Institution approved successfully'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         _loadInstitutions();
//       } else {
//         throw Exception('Failed to approve institution');
//       }
//     } catch (e) {
//       print('❌ Error approving institution: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to approve institution: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   void _showRejectDialog(int institutionId, String institutionName) {
//     TextEditingController reasonController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Reject Institution'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Reason for rejecting $institutionName:'),
//             SizedBox(height: 16),
//             TextField(
//               controller: reasonController,
//               decoration: InputDecoration(
//                 hintText: 'Enter rejection reason...',
//                 border: OutlineInputBorder(),
//               ),
//               maxLines: 3,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (reasonController.text.trim().isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Please enter a rejection reason')),
//                 );
//                 return;
//               }

//               Navigator.pop(context);
//               await _rejectInstitution(institutionId, reasonController.text);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: Text('Reject', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _rejectInstitution(int institutionId, String reason) async {
//     try {
//       final success = await AdminApiService.rejectInstitution(institutionId, reason: reason);

//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Institution rejected successfully'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         _loadInstitutions();
//       } else {
//         throw Exception('Failed to reject institution');
//       }
//     } catch (e) {
//       print('❌ Error rejecting institution: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to reject institution: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   Widget _buildInstitutionCard(Institution institution) {
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       color: AppColors.surface,
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Expanded(
//                   child: Text(
//                     institution.name,
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 _buildStatusBadge(institution.approvalStatus),
//               ],
//             ),
//             SizedBox(height: 8),
//             if (institution.description != null)
//               Text(
//                 institution.description!,
//                 style: TextStyle(color: Colors.grey[600]),
//               ),
//             SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.location_on, size: 16, color: Colors.grey),
//                 SizedBox(width: 4),
//                 Text('${institution.city} - ${institution.region ?? ""}'),
//               ],
//             ),
//             SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.star, size: 16, color: Colors.amber),
//                 SizedBox(width: 4),
//                 Text('Rating: ${institution.rating ?? "Not available"}'),
//               ],
//             ),
//             SizedBox(height: 12),
//             if (institution.approvalStatus == 'Pending') _buildPendingActions(institution),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusBadge(String status) {
//     Color color;
//     String text;

//     switch (status) {
//       case 'Approved':
//         color = Colors.green;
//         text = 'Approved';
//         break;
//       case 'Pending':
//         color = Colors.orange;
//         text = 'Pending';
//         break;
//       case 'Rejected':
//         color = Colors.red;
//         text = 'Rejected';
//         break;
//       case 'Suspended':
//         color = Colors.grey;
//         text = 'Suspended';
//         break;
//       default:
//         color = Colors.grey;
//         text = status;
//     }

//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: color),
//       ),
//       child: Text(
//         text,
//         style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
//       ),
//     );
//   }

//   Widget _buildPendingActions(Institution institution) {
//     return Row(
//       children: [
//         Expanded(
//           child: ElevatedButton.icon(
//             onPressed: () => _approveInstitution(institution.institutionId),
//             icon: Icon(Icons.check, size: 18),
//             label: Text('Approve'),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//           ),
//         ),
//         SizedBox(width: 8),
//         Expanded(
//           child: OutlinedButton.icon(
//             onPressed: () => _showRejectDialog(institution.institutionId, institution.name),
//             icon: Icon(Icons.close, size: 18),
//             label: Text('Reject'),
//             style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         title: Text('Institution Management'),
//         backgroundColor: AppColors.primary,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadInstitutions,
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search institutions...',
//                 prefixIcon: Icon(Icons.search),
//                 filled: true,
//                 fillColor: AppColors.surface,
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                 contentPadding: EdgeInsets.symmetric(horizontal: 16),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//                 Future.delayed(Duration(milliseconds: 500), () {
//                   if (_searchQuery == value) {
//                     _currentPage = 1;
//                     _loadInstitutions();
//                   }
//                 });
//               },
//             ),
//           ),

//           if (_isLoading)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
//                     ),
//                     SizedBox(height: 16),
//                     Text('Loading institutions...'),
//                   ],
//                 ),
//               ),
//             )
//           else if (_errorMessage.isNotEmpty)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.error_outline, color: Colors.red, size: 64),
//                     SizedBox(height: 16),
//                     Text(_errorMessage, textAlign: TextAlign.center),
//                     SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: _loadInstitutions,
//                       child: Text('Retry'),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           else if (_institutions.isEmpty)
//               Expanded(
//                 child: Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.business, size: 64, color: Colors.grey),
//                       SizedBox(height: 16),
//                       Text('No institutions found'),
//                       SizedBox(height: 8),
//                       Text(
//                         'Registered institutions will appear here',
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//             else
//               Expanded(
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Total institutions: ${_institutions.length}',
//                             style: TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                           Text(
//                             'Page $_currentPage of $_totalPages',
//                             style: TextStyle(color: Colors.grey),
//                           ),
//                         ],
//                       ),
//                     ),

//                     Expanded(
//                       child: ListView.builder(
//                         itemCount: _institutions.length,
//                         itemBuilder: (context, index) {
//                           return _buildInstitutionCard(_institutions[index]);
//                         },
//                       ),
//                     ),

//                     if (_totalPages > 1) _buildPagination(),
//                   ],
//                 ),
//               ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPagination() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         border: Border(top: BorderSide(color: Colors.grey[300]!)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           IconButton(
//             icon: Icon(Icons.arrow_back_ios),
//             onPressed: _currentPage > 1 ? () {
//               setState(() => _currentPage--);
//               _loadInstitutions();
//             } : null,
//           ),
//           Text('Page $_currentPage of $_totalPages'),
//           IconButton(
//             icon: Icon(Icons.arrow_forward_ios),
//             onPressed: _currentPage < _totalPages ? () {
//               setState(() => _currentPage++);
//               _loadInstitutions();
//             } : null,
//           ),
//         ],
//       ),
//     );
//   }
// }