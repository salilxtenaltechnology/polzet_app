// ignore_for_file: unused_field, unused_element, non_constant_identifier_names, use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' hide MultipartFile, Response;
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import '../data/token/shared_preferences.dart';
import '../mixin/utility_mixins.dart';
import '../models/global search/global_search_model.dart';
import '../models/global search/recent_search.dart';
import '../models/insights/insights_model.dart';
import '../models/like/like_uers_model.dart';
import '../models/message/message_model.dart';
import '../models/poll/poll_results_model.dart';
import '../models/posts/homefeed_posts_model.dart';
import '../models/posts/single_post_model.dart';
import '../models/posts/user_post_model.dart';
import '../models/public/public_profile_model.dart';
import '../models/search/hashtag/hashtag_posts_list_model.dart';
import '../models/user/suggestionsb users/suggestions_users_model.dart';
import '../models/voters/top_voters_model.dart';
import '../provider/connection_provider.dart';
import '../provider/user_provider.dart';
import '../screens/home/home_imports.dart';
import '../screens/terms_acceptance/terms_acceptance.dart';
import '../widgets/show_toast.dart';
import 'api_config.dart';
import 'app_api.dart';
import 'services/fcm/fcm_service.dart';
import 'services/notification/notification_services.dart';

class ApiService with UtilityMixin {
  final SharedPrefService _prefService = SharedPrefService();
  final NotificationService _notificationService = NotificationService();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          final ignore500 = e.requestOptions.headers['Ignore-500'] == 'true';
          if (!ignore500 &&
              e.response?.statusCode != null &&
              e.response!.statusCode! >= 500) {
            ServerMonitor.reportServerDown();
          }
          return handler.next(e);
        },
      ),
    );
  }

  static bool simulateError = false;
  static String simulateErrorType = 'none';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (status) => status != null && status < 500,
      responseType: ResponseType.json,
    ),
  );

  static const int _maxFileSizeMB = 10;
  static const String _errorMessageGeneric = 'An unexpected error occurred';
  static const String _errorMessageNetwork = 'Network error. Please try again.';
  static const String _errorMessageAuth = 'Unauthorized. Please login again.';

  /// Get authorization headers with access token
  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await SharedPrefService.getToken();
    return {
      'Authorization': 'Bearer ${accessToken ?? ''}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  String _handleDioError(
    DioException e, {
    String defaultMessage = _errorMessageGeneric,
  }) {
    if (kDebugMode) {
      debugPrint('DioException: ${e.message}');
      debugPrint('Response: ${e.response?.data}');
    }

    final statusCode = e.response?.statusCode;

    if (statusCode == 401) return _errorMessageAuth;
    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (statusCode == 404) return 'The requested resource was not found.';

    // Server errors (500+)
    if (statusCode != null && statusCode >= 500) {
      return 'We encountered a temporary issue with our servers. Please try again.';
    }

    // Network & Timeout Errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'The server is temporarily unavailable due to a connection timeout.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection available.';
    }

    // Only passthrough backend error string if it is a 4xx validation/client error.
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      if (e.response?.data != null && e.response?.data is Map) {
        return e.response?.data['message']?.toString() ??
            e.response?.data['detail']?.toString() ??
            defaultMessage;
      }
    }

    return defaultMessage;
  }

  /// Public wrapper for _handleDioError to use in other screens/classes
  String handleDioError(
    DioException e, {
    String defaultMessage = _errorMessageGeneric,
  }) {
    return _handleDioError(e, defaultMessage: defaultMessage);
  }

  /// Validate file size
  Future<bool> _validateFileSize(
    File file, {
    int maxSizeMB = _maxFileSizeMB,
  }) async {
    final fileSizeInBytes = await file.length();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    return fileSizeInMB <= maxSizeMB;
  }

  // ==================== AUTHENTICATION ====================

  Future<void> loginUser({
    required String email_username,
    required String password,
    required BuildContext context,
    void Function(String? passwordError, String? emailOrMobileError)? onError,
    VoidCallback? onSuccess,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'username_or_email': email_username, 'password': password},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('response.data type: ${response.data.runtimeType}');
        debugPrint('response.data: ${response.data}');
        Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          data = response.data as Map<String, dynamic>;
        }
        final accessToken = data['access_token'] ?? '';
        final refreshToken = data['refresh_token'] ?? '';
        final dynamic isNewUserRaw = data['is_new_user'];
        final bool isNewUser =
            isNewUserRaw == true || isNewUserRaw == 'true' || isNewUserRaw == 1;

        debugPrint('isNewUserRaw: $isNewUserRaw (${isNewUserRaw.runtimeType})');
        debugPrint('isNewUser resolved: $isNewUser');

        await SharedPrefService.setToken(accessToken);
        await SharedPrefService.setRefreshToken(refreshToken);
        await _notificationService.initialize();
        await _notificationService.connectToWebSocket(accessToken);

        // Register FCM Token immediately
        final fcmToken = await _notificationService.getFCMToken();
        if (fcmToken != null) {
          final platform = Platform.isAndroid ? 'android' : 'ios';
          await FcmApiService.registerFcmToken(fcmToken, platform);
        }

        if (context.mounted) {
          Provider.of<UserProvider>(context, listen: false);

          final Widget destination = isNewUser
              ? const TermsAcceptance(isNewUser: true)
              : const HomeScreen(initialIndex: 0);

          Navigator.pushAndRemoveUntil(
            context,
            PageTransition(
              type: PageTransitionType.fade,
              duration: const Duration(milliseconds: 200),
              child: destination,
            ),
            (route) => false,
          );
        }

        if (onSuccess != null) {
          onSuccess();
        }

        showToast(message: 'Login successful!');
      } else if (response.statusCode == 400) {
        final data = response.data;
        String? passErr;
        String? emailOrMobileErr;
        if (data is Map) {
          final errors = data['errors'];
          if (errors is Map) {
            final pErr = errors['password'];
            if (pErr is List && pErr.isNotEmpty) {
              passErr = pErr.first.toString();
            } else if (pErr is String) {
              passErr = pErr;
            }

            final uErr = errors['username_or_email'];
            if (uErr is List && uErr.isNotEmpty) {
              emailOrMobileErr = uErr.first.toString();
            } else if (uErr is String) {
              emailOrMobileErr = uErr;
            }
          }
        }
        if (onError != null) {
          onError(passErr, emailOrMobileErr);
        }
        // showToast(message: 'Error: ${response.data['message']}');
      }
    } on DioException catch (e) {
      String? passErr;
      String? emailOrMobileErr;
      if (e.response != null && e.response?.data != null) {
        var data = e.response?.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }
        if (data is Map) {
          final errors = data['errors'];
          if (errors is Map) {
            final pErr = errors['password'];
            if (pErr is List && pErr.isNotEmpty) {
              passErr = pErr.first.toString();
            } else if (pErr is String) {
              passErr = pErr;
            }

            final uErr = errors['username_or_email'];
            if (uErr is List && uErr.isNotEmpty) {
              emailOrMobileErr = uErr.first.toString();
            } else if (uErr is String) {
              emailOrMobileErr = uErr;
            }
          }
        }
      }
      if (passErr == null && emailOrMobileErr == null) {
        emailOrMobileErr = _handleDioError(e, defaultMessage: 'Login failed');
      }
      if (onError != null) {
        onError(passErr, emailOrMobileErr);
      }
      // showToast(message: _handleDioError(e, defaultMessage: 'Login failed'));
    }
  }

  Future socialLogin(String googleToken) async {
    try {
      //  debugPrint('📤 socialLogin token: $googleToken');

      final response = await _dio.post(
        ApiConstants.socialAuth,
        data: FormData.fromMap({
          // ← Change this
          'provider': 'google',
          'id_token': googleToken,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData is String) {
          return jsonDecode(responseData);
        }
        return responseData;
      }

      throw Exception('Unexpected status code: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('❌ socialLogin DioException: ${e.message}');
      debugPrint(
        '❌ socialLogin DioException response data: ${e.response?.data}',
      );
      debugPrint(
        '❌ socialLogin DioException response statusCode: ${e.response?.statusCode}',
      );

      String errorMessage = 'Social login failed';
      if (e.response?.data != null) {
        final errorData = e.response!.data;
        if (errorData is Map) {
          errorMessage =
              errorData['message']?.toString() ??
              errorData['detail']?.toString() ??
              errorData['error']?.toString() ??
              errorMessage;
        } else if (errorData is String) {
          try {
            final decoded = jsonDecode(errorData);
            if (decoded is Map) {
              errorMessage =
                  decoded['message']?.toString() ??
                  decoded['detail']?.toString() ??
                  decoded['error']?.toString() ??
                  errorMessage;
            }
          } catch (_) {}
        }
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      rethrow;
    }
  }

  /// POST /check_username/
  Future<Map<String, dynamic>> checkUsername({required String username}) async {
    try {
      final response = await _dio.post(
        ApiConstants.checkUsername,
        data: {'username': username},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      final available =
          (data['data']?['available'] ?? data['available']) == true;
      final message =
          data['data']?['message']?.toString() ??
          data['message']?.toString() ??
          '';

      return {'available': available, 'message': message};
    } on DioException catch (e) {
      return {
        'available': false,
        'message':
            e.response?.data?['message']?.toString() ??
            'Failed to check username',
      };
    } catch (e) {
      return {'available': false, 'message': 'Something went wrong'};
    }
  }

  // Send OTP - Email
  Future<Map<String, dynamic>> sendEmailOtp({required String email}) async {
    try {
      final response = await _dio.post(
        ApiConstants.emailOtp,
        data: {'email': email},
      );
      debugPrint('sendEmailOtp response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        'sendEmailOtp error: ${e.response?.statusCode} ${e.response?.data}',
      );
      rethrow;
    }
  }

  // Send OTP - Mobile
  Future<Map<String, dynamic>> sendMobileOtp({
    required String phoneNumber,
    required String countryCode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.mobileOtp,
        data: {'phone_number': phoneNumber, 'country_code': countryCode},
      );
      debugPrint('sendMobileOtp response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        'sendMobileOtp error: ${e.response?.statusCode} ${e.response?.data}',
      );
      rethrow;
    }
  }

  // Verify Email OTP
  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyEmailOtp, // /validate_otp
        data: {'email': email, 'otp': otp},
      );
      debugPrint('verifyEmailOtp response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        'verifyEmailOtp error: ${e.response?.statusCode} ${e.response?.data}',
      );
      rethrow;
    }
  }

  // Verify Mobile OTP
  Future<Map<String, dynamic>> verifyMobileOtp({
    String? phoneNumber,
    String? countryCode,
    String? otp,
    String? idToken,
  }) async {
    try {
      final Map<String, dynamic> body = idToken != null
          ? {'id_token': idToken}
          : {
              'phone_number': phoneNumber,
              'country_code': countryCode,
              'otp': otp,
            };
      final response = await _dio.post(
        ApiConstants.verifyMobileOtp,
        data: body,
      );
      debugPrint('verifyMobileOtp response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        'verifyMobileOtp error: ${e.response?.statusCode} ${e.response?.data}',
      );
      rethrow;
    }
  }

  /// [identifier] — email address or phone number
  Future<Map<String, dynamic>> forgotPasswordSendOtp({
    required String identifier,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.forgotPasswordEmail,
        data: {'identifier': identifier},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          // Don't throw on 4xx — we handle status manually
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      if (data['status'] == 'success') {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP sent successfully',
          'data': data['data'],
        };
      } else {
        final errors = data['errors'];
        String errorMessage = data['message'] ?? 'Something went wrong';

        // Extract first error from errors.identifier array if present
        if (errors is Map && errors['identifier'] is List) {
          final identifierErrors = errors['identifier'] as List;
          if (identifierErrors.isNotEmpty) {
            errorMessage = identifierErrors.first.toString();
          }
        }

        return {'success': false, 'message': errorMessage};
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final errors = data is Map ? data['errors'] : null;

      String errorMessage = 'Something went wrong';

      if (errors is Map && errors['identifier'] is List) {
        final identifierErrors = errors['identifier'] as List;
        if (identifierErrors.isNotEmpty) {
          errorMessage = identifierErrors.first.toString();
        }
      } else if (data is Map && data['message'] != null) {
        errorMessage = data['message'].toString();
      } else {
        errorMessage = e.message ?? 'Connection error';
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: ${e.toString()}'};
    }
  }

  /// [identifier] — email or phone number
  /// [otp] — 6-digit OTP
  Future<Map<String, dynamic>> forgotPasswordVerifyOtp({
    required String identifier,
    String? otp,
    String? idToken,
  }) async {
    debugPrint('BODY = identifier: $identifier, otp: $otp, id_token: $idToken');
    try {
      final Map<String, dynamic> body = idToken != null
          ? {
              'identifier': identifier,
              'id_token': idToken,
              if (otp != null) 'otp': otp,
            }
          : {'identifier': identifier, 'otp': otp};
      final response = await _dio.post(
        ApiConstants.forgotPasswordVerify,
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      if (data['status'] == 'success') {
        final resetToken = data['data']?['reset_token'] ?? '';
        return {
          'success': true,
          'reset_token': resetToken,
          'message': data['message'] ?? 'OTP verified successfully',
        };
      } else {
        final errors = data['errors'];
        String errorMessage = data['message'] ?? 'Verification failed';

        if (errors is Map && errors['non_field_errors'] is List) {
          final list = errors['non_field_errors'] as List;
          if (list.isNotEmpty) errorMessage = list.first.toString();
        }

        return {'success': false, 'message': errorMessage};
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String errorMessage = 'Something went wrong';

      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors['non_field_errors'] is List) {
          final list = errors['non_field_errors'] as List;
          if (list.isNotEmpty) errorMessage = list.first.toString();
        } else {
          errorMessage = data['message']?.toString() ?? errorMessage;
        }
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: ${e.toString()}'};
    }
  }

  /// POST /forgot_new_password
  /// [resetToken] — token received from OTP verify step
  /// [newPassword] — user's new password
  Future<Map<String, dynamic>> forgotNewPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.forgotNewPassword,
        data: {'reset_token': resetToken, 'new_password': newPassword},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      if (data['status'] == 'success') {
        return {
          'success': true,
          'message':
              data['data']?.toString() ?? 'Password updated successfully',
        };
      } else {
        final errors = data['errors'];
        final errorMessage = (errors != null && errors.toString().isNotEmpty)
            ? errors.toString()
            : data['message']?.toString() ?? 'Failed to update password';

        return {'success': false, 'message': errorMessage};
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String errorMessage = 'Something went wrong';

      if (data is Map) {
        final errors = data['errors'];
        errorMessage = (errors != null && errors.toString().isNotEmpty)
            ? errors.toString()
            : data['message']?.toString() ?? errorMessage;
      } else {
        errorMessage = e.message ?? errorMessage;
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> acceptPrivacyStatus({
    required String status,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.privacyPolicy,
        data: FormData.fromMap({'status': status}),
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'message': 'Failed to update privacy status'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(
          e,
          defaultMessage: 'Failed to update privacy status',
        ),
      };
    }
  }

  // ==================== USER PROFILE ====================

  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      final accessToken = await SharedPrefService.getToken();
      if (accessToken == null || accessToken.isEmpty) return null;

      final response = await _dio.get(
        ApiConstants.userProfile,
        options: Options(headers: await _getAuthHeaders()),
      );

      final String userId = response.data['id'].toString();
      await _prefService.saveUserId(userId);

      return response.statusCode == 200 ? response.data : null;
    } on DioException catch (e) {
      debugPrint('Error fetching current user data: ${e.message}');
      return null;
    }
  }

  // Note: Implemented POST Method User Update Profile
  Future<String> updateProfile({
    required String firstName,
    required String lastName,
    required String bio,
    String? dob,
    String? gender,
    List<dynamic>? interests,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'bio': bio,
          if (dob != null && dob.isNotEmpty) 'dob': dob,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          if (interests != null) 'interests': interests,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      debugPrint('response: $response');

      if (response.statusCode == 200) {
        showToast(message: 'Profile updated!');
        return '';
      }

      final message = response.data['message'] ?? 'Failed to update profile';
      showToast(message: message);
      return message;
    } on DioException catch (e) {
      final message = _handleDioError(
        e,
        defaultMessage: 'Failed to update profile',
      );
      showToast(message: message);
      return message;
    }
  }

  // Note: Implemented PATCH Method User Update Interests
  Future<bool> updateUserInterests({required List<dynamic> interests}) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {
          'interests': interests,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return true;
      }

      final message = response.data['message'] ?? 'Failed to update interests';
      showToast(message: message);
      return false;
    } on DioException catch (e) {
      final message = _handleDioError(
        e,
        defaultMessage: 'Failed to update interests',
      );
      showToast(message: message);
      return false;
    }
  }

  // Note: Implemented PATCH Method User Update Country
  Future<bool> updateCountry({
    required String country,
  }) async {
    try {
      var response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {
          "country": country,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      debugPrint('updateCountry response: ${response.data}');

      bool isSuccess = (response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map &&
          response.data['status'] != 'error' &&
          response.data['errors'] == null;

      // If backend returned "Object with code=... does not exist", retry with alternative case (e.g. lowercase)
      if (!isSuccess && response.data is Map) {
        final errStr = response.data.toString();
        if (errStr.contains('does not exist') || errStr.contains('code=')) {
          final altCountry = country == country.toLowerCase()
              ? country.toUpperCase()
              : country.toLowerCase();
          debugPrint('Retrying updateCountry with alternative case: $altCountry');

          final retryResponse = await _dio.patch(
            ApiConstants.updateProfile,
            data: {
              "country": altCountry,
            },
            options: Options(headers: await _getAuthHeaders()),
          );

          debugPrint('updateCountry retry response: ${retryResponse.data}');

          if ((retryResponse.statusCode == 200 || retryResponse.statusCode == 201) &&
              retryResponse.data is Map &&
              retryResponse.data['status'] != 'error' &&
              retryResponse.data['errors'] == null) {
            showToast(message: 'Country updated successfully!');
            return true;
          } else {
            response = retryResponse;
          }
        }
      }

      if (isSuccess) {
        return true;
      }

      final message = _extractApiErrorMessage(response.data, 'Failed to update country');
      showToast(message: message);
      return false;
    } on DioException catch (e) {
      final message = _handleDioError(
        e,
        defaultMessage: 'Failed to update country',
      );
      showToast(message: message);
      return false;
    }
  }

  String _extractApiErrorMessage(dynamic data, String defaultMsg) {
    if (data is Map) {
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
      if (data['errors'] != null) {
        if (data['errors'] is Map) {
          final map = data['errors'] as Map;
          final firstKey = map.keys.firstOrNull;
          if (firstKey != null) {
            final val = map[firstKey];
            if (val is List && val.isNotEmpty) {
              return val.first.toString();
            }
            return val.toString();
          }
        } else if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          return (data['errors'] as List).first.toString();
        } else {
          return data['errors'].toString();
        }
      }
    }
    return defaultMsg;
  }

  // Note: Implemented POST Method User Update Username
  Future<String> updateUsername({required String newUsername}) async {
    try {
      final response = await _dio.post(
        ApiConstants.updateUsername,
        data: {'new_username': newUsername},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Username updated!');
        return '';
      }

      // Since validateStatus allows < 500, we handle 4xx here
      if (response.data != null) {
        final data = response.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        } else if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map && decoded['message'] != null) {
              return decoded['message'].toString();
            }
          } catch (_) {}
        }
      }

      return 'Failed to update username';
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        // handles both Map and already-decoded cases
        final message = data is Map ? data['message']?.toString() : null;
        if (message != null && message.isNotEmpty) return message;
      }
      return _handleDioError(e, defaultMessage: 'Failed to update username');
    }
  }
  /// Fetches the list of available interests (id, name, icon).
  Future<Map<String, dynamic>> getInterestList() async {
    try {
      final response = await _dio.get(
        ApiConstants.interests,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'status': 'success', 'data': response.data};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> requestEmailChangeOtp({
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/profile/verify-email-request',
        data: FormData.fromMap({'email': email}),
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // Handle known API error shape, fallback to generic message
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Something went wrong')
          : 'Something went wrong';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> confirmEmailChangeOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/profile/verify-email-confirm',
        data: FormData.fromMap({'email': email, 'otp': otp}),
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Something went wrong')
          : 'Something went wrong';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> numberVerifyRequest({
    required String countryCode,
    required String mobileNumber,
  }) async {
    try {
      final formData = FormData.fromMap({
        'country_code': countryCode,
        'mobile_number': mobileNumber,
      });

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/profile/verify_phone_request',
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> numberOtpVerify({
  required String countryCode,
  required String mobileNumber,
  String? otp,
  String? firebaseToken,
}) async {
  assert(
    otp != null || firebaseToken != null,
    'Either otp or firebaseToken must be provided',
  );

  try {
    final formData = FormData.fromMap({
      'country_code': countryCode,
      'mobile_number': mobileNumber,
      if (otp != null) 'otp': otp,
      if (firebaseToken != null) 'firebase_token': firebaseToken,
    });

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/profile/verify_phone_confirm',
      data: formData,
      options: Options(headers: await _getAuthHeaders()),
    );

    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw _handleDioError(e);
  }
}

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
    required void Function(
      String? currentPasswordError,
      String? newPasswordError,
      String? confirmPasswordError,
    )
    onError,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.updatePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_new_password': confirmNewPassword,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map && data['status'] == 'error') {
          // It's an error disguised as a 200
          final errors = data['errors'];
          String? curErr, newErr, conErr;
          if (errors is Map) {
            String? extract(String key) {
              if (errors[key] is List && (errors[key] as List).isNotEmpty) {
                return (errors[key] as List).first.toString();
              } else if (errors[key] is String) {
                return errors[key].toString();
              }
              return null;
            }

            curErr = extract('current_password');
            newErr = extract('new_password');
            conErr = extract('confirm_new_password');
          }
          onError(curErr, newErr, conErr);
          return data['message']?.toString() ?? 'Failed to update password';
        }

        showToast(message: 'Password updated successfully!');
        return '';
      }

      if (response.statusCode == 400) {
        final data = response.data;
        if (data is Map && data['status'] == 'error') {
          final errors = data['errors'];
          String? curErr, newErr, conErr;
          if (errors is Map) {
            String? extract(String key) {
              if (errors[key] is List && (errors[key] as List).isNotEmpty) {
                return (errors[key] as List).first.toString();
              } else if (errors[key] is String) {
                return errors[key].toString();
              }
              return null;
            }

            curErr = extract('current_password');
            newErr = extract('new_password');
            conErr = extract('confirm_new_password');
          }
          onError(curErr, newErr, conErr);
          return data['message']?.toString() ?? 'Failed to update password';
        }
      }

      return 'Failed to update password';
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        var data = e.response?.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }

        String? curErr;
        String? newErr;
        String? conErr;

        if (data is Map) {
          final errors = data['errors'];
          if (errors is Map) {
            String? extract(String key) {
              if (errors[key] is List && (errors[key] as List).isNotEmpty) {
                return (errors[key] as List).first.toString();
              } else if (errors[key] is String) {
                return errors[key].toString();
              }
              return null;
            }

            curErr = extract('current_password');
            newErr = extract('new_password');
            conErr = extract('confirm_new_password');
          }
        }

        onError(curErr, newErr, conErr);

        return data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Failed to update password';
      }
      return _handleDioError(e, defaultMessage: 'Failed to update password');
    }
  }

  Future<String> setPassword(String password) async {
    // final String? googleToken = await SharedPrefService.getString(
    //   'jwt_google_token',
    // );

    try {
      final response = await _dio.post(
        ApiConstants.setPassword,
        options: Options(headers: await _getAuthHeaders()),
        data: {'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return '';
      }

      return response.data['message'] ?? 'Failed to set password';
    } on DioException catch (e) {
      debugPrint('❌ DioException status: ${e.response?.statusCode}');
      debugPrint('❌ DioException data: ${e.response?.data}');

      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] ??
            data['detail'] ??
            data['error'] ??
            'Failed to set password';
      }

      return 'Failed to set password';
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return 'Unexpected error occurred';
    }
  }

  // NOTE : Implemented PATCH Method User Update Private Account
  Future<String> updateAccountPrivacy({required bool isPrivate}) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {'is_private': isPrivate.toString()},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final message = isPrivate
            ? 'Account is now private'
            : 'Account is now public';
        showToast(message: message);
        return message;
      }

      final message = response.data['message'] ?? 'Failed to update privacy';
      showToast(message: message);
      return message;
    } on DioException catch (e) {
      final message = _handleDioError(
        e,
        defaultMessage: 'Failed to update privacy',
      );
      showToast(message: message);
      return message;
    }
  }

  Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final response = await _dio.delete(
        ApiConstants.deleteAccount,
        data: {'password': password},
        options: Options(headers: await _getAuthHeaders()),
      );

      final dynamic resData = response.data;
      Map<String, dynamic> data = {};
      if (resData is Map<String, dynamic>) {
        data = resData;
      } else if (resData is String) {
        try {
          data = jsonDecode(resData) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        final isSuccess = data['status'] == 'success' ||
            data['success'] == true ||
            data['status'] == null;
        return {
          'success': isSuccess,
          'message': data['message'] ?? 'Account deleted permanently',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete account',
        };
      }
    } on DioException catch (e) {
      String message = 'Failed to delete account';
      final dynamic resData = e.response?.data;
      if (resData is Map) {
        message = resData['message']?.toString() ??
            resData['detail']?.toString() ??
            _handleDioError(e, defaultMessage: 'Failed to delete account');
      } else {
        message = _handleDioError(e, defaultMessage: 'Failed to delete account');
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  // ==================== NOTIFICATIONS ====================

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get(
        ApiConstants.unreadNotificationCount,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return response.data['unread_count'] as int;
      }
      return 0;
    } on DioException catch (e) {
      debugPrint('Error fetching unread notification count: $e');
      return 0;
    }
  }

  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await _dio.post(
        ApiConstants.markNotificationRead,
        data: {'id': notificationId},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.deleteNotification}/$notificationId/delete',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  Future<bool> clearAllNotifications() async {
    try {
      final response = await _dio.post(
        ApiConstants.clearAllNotifications,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Error clearing all notifications: $e');
      return false;
    }
  }

  //*==================== IMAGE UPLOADS ====================*//

  // Upload profile picture
  Future<String> uploadProfileImage(File file) async {
    try {
      if (!await _validateFileSize(file)) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }

      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(
          file.path,
          filename: path.basename(file.path),
        ),
      });

      final response = await _dio.put(
        ApiConstants.profileImage,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Profile picture updated!');
        return '';
      }
      return 'Failed to upload profile photo';
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }
      return _handleDioError(e, defaultMessage: 'Image upload failed');
    }
  }

  // Note: Implemented PUT Method User Cover Image
  Future<String> uploadCoverPhoto(File file) async {
    try {
      if (!await _validateFileSize(file)) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }

      final formData = FormData.fromMap({
        'cover_photo': await MultipartFile.fromFile(
          file.path,
          filename: path.basename(file.path),
        ),
      });

      final response = await _dio.put(
        ApiConstants.coverImage,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        showToast(message: 'Cover photo updated!');
        return '';
      }
      return 'Failed to upload cover photo';
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return 'Image too large. Maximum size allowed is ${_maxFileSizeMB}MB.';
      }
      return _handleDioError(e, defaultMessage: 'Image upload failed');
    }
  }

  // ==================== POSTS ====================

  Future<Map<String, dynamic>> generateQuestion({required String input}) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/trigger_ai',
        data: jsonEncode({'mode': "improve_question", 'input': input}),
        options: Options(
          headers: await _getAuthHeaders(),
          contentType: 'application/json',
        ),
      );

      final responseData = response.data;
      if (responseData is String) {
        return jsonDecode(responseData) as Map<String, dynamic>;
      }
      return responseData as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            return jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
      throw Exception(
        _handleDioError(e, defaultMessage: 'Failed to improve question'),
      );
    }
  }

  Future<Map<String, dynamic>> generateOptions({required String input}) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/trigger_ai',
        data: jsonEncode({'mode': "generate_options", 'input': input}),
        options: Options(
          headers: await _getAuthHeaders(),
          contentType: 'application/json',
        ),
      );

      final responseData = response.data;
      if (responseData is String) {
        return jsonDecode(responseData) as Map<String, dynamic>;
      }
      return responseData as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            return jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
      throw Exception(
        'Failed to generate options: ${e.response?.data ?? e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> generateDescription({
    required String question,
    required List<String> options,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final inputPayload = {"question": question, "options": options};

      // 1. Try sending raw JSON payload matching Postman format
      var response = await _dio.post(
        '${ApiConfig.baseUrl}/trigger_ai',
        data: jsonEncode({
          "mode": "generate_description",
          "input": inputPayload,
        }),
        options: Options(headers: headers, contentType: 'application/json'),
      );

      Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data as Map);
      } else {
        data = {};
      }

      // 2. If response contains validation error (e.g. input CharField string validation), retry with stringified input
      if ((response.statusCode != null && response.statusCode! >= 400) ||
          data['status'] == 'error' ||
          data['errors'] != null) {
        debugPrint(
          'First attempt returned validation error: ${data['errors']}. Retrying with stringified input...',
        );
        final retryResponse = await _dio.post(
          '${ApiConfig.baseUrl}/trigger_ai',
          data: jsonEncode({
            "mode": "generate_description",
            "input": jsonEncode(inputPayload),
          }),
          options: Options(headers: headers, contentType: 'application/json'),
        );

        Map<String, dynamic> retryData;
        if (retryResponse.data is String) {
          retryData =
              jsonDecode(retryResponse.data as String) as Map<String, dynamic>;
        } else if (retryResponse.data is Map) {
          retryData = Map<String, dynamic>.from(retryResponse.data as Map);
        } else {
          retryData = {};
        }

        if (retryData['description'] != null || retryData['success'] == true) {
          return retryData;
        }
      }

      return data;
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            return jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
      throw Exception(
        _handleDioError(e, defaultMessage: 'Failed to generate description'),
      );
    }
  }

  Future<Map<String, dynamic>> generateHashtags({
    required String question,
    required String description,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final inputPayload = {"question": question, "description": description};

      // 1. Try sending raw JSON payload matching Postman format
      var response = await _dio.post(
        '${ApiConfig.baseUrl}/trigger_ai',
        data: jsonEncode({"mode": "generate_hashtags", "input": inputPayload}),
        options: Options(headers: headers, contentType: 'application/json'),
      );

      Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data as Map);
      } else {
        data = {};
      }

      // 2. If response contains validation error, retry with stringified input
      if ((response.statusCode != null && response.statusCode! >= 400) ||
          data['status'] == 'error' ||
          data['errors'] != null) {
        debugPrint(
          'First attempt returned validation error: ${data['errors']}. Retrying generateHashtags with stringified input...',
        );
        final retryResponse = await _dio.post(
          '${ApiConfig.baseUrl}/trigger_ai',
          data: jsonEncode({
            "mode": "generate_hashtags",
            "input": jsonEncode(inputPayload),
          }),
          options: Options(headers: headers, contentType: 'application/json'),
        );

        Map<String, dynamic> retryData;
        if (retryResponse.data is String) {
          retryData =
              jsonDecode(retryResponse.data as String) as Map<String, dynamic>;
        } else if (retryResponse.data is Map) {
          retryData = Map<String, dynamic>.from(retryResponse.data as Map);
        } else {
          retryData = {};
        }

        if (retryData['hashtags'] != null || retryData['success'] == true) {
          return retryData;
        }
      }

      return data;
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            return jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
      throw Exception(
        _handleDioError(e, defaultMessage: 'Failed to generate hashtags'),
      );
    }
  }

  // Battel poll
  Future<Map<String, dynamic>> createBattlePoll({
    required String description,
    required String question,
    required List<String> pollOptions,
  }) async {
    try {
      final formData = FormData();

      formData.fields
        ..add(MapEntry('question', question))
        ..add(MapEntry('description', description))
        ..add(const MapEntry('poll_type', 'battle'))
        ..add(const MapEntry('voting_type', 'single_choice'));

      for (final option in pollOptions) {
        formData.fields.add(MapEntry('poll_options', option));
      }

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/posts',
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? 'Failed to create battle poll',
      );
    }
  }

  // Suggestion users
  Future<UserSuggestionsModel> fetchUserSuggestions({int? page}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (page != null) queryParams['page'] = page;

      final response = await _dio.get(
        ApiConstants.suggestionUsers,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;

        return UserSuggestionsModel.fromJson(jsonData);
      }
      throw Exception('Failed to load suggestions: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching user suggestions: $e');
      throw Exception('Error fetching user suggestions: $e');
    }
  }

  static Future<HomeFeedResponse> fetchHomeFeedPosts({
    int? page,
    String? snapshot,
    bool isPagination = false,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      final Map<String, dynamic> queryParams = {};
      if (page != null) queryParams['page'] = page;
      if (snapshot != null) queryParams['snapshot'] = snapshot;

      final response = await _dio.get(
        ApiConstants.homeFeed,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            if (isPagination) 'Ignore-500': 'true',
          },
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        return HomeFeedResponse.fromJson(jsonData);
      }
      throw Exception('Failed to load posts: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching home feed: $e');
      throw Exception('Error fetching posts: $e');
    }
  }

  Future<SinglePostModel> getSinglePost(String username, dynamic postId) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw Exception('Cannot fetch single post: username is empty');
    }
    try {
      final response = await _dio.get(
        '${ApiConstants.singlePost}/$cleanUsername/$postId/',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        return SinglePostModel.fromJson(jsonData);
      }
      throw Exception('Failed to load post: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching single post: $e');
      throw Exception('Error fetching single post: $e');
    }
  }

  /// Fetch user posts with polls things
  Future<List<UserPostModel>> fetchPostsPolls(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      throw Exception('Cannot fetch user posts: username is empty');
    }
    try {
      final response = await _dio.get(
        '${ApiConstants.userPosts}/$cleanUsername',
        options: Options(headers: await _getAuthHeaders()),
      );
      final postResponse = UserPostResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return postResponse.results;
    } on DioException catch (e) {
      debugPrint('Error fetching posts: $e');
      rethrow;
    }
  }

  /// Fetch only poll things posts
  Future<List<UserPostModel>> fetchOnlyPollPosts(String username) async {
    final allPosts = await fetchPostsPolls(username);
    return allPosts.where((post) => post.polls.isNotEmpty).toList();
  }

  // Fetch user posts with images
  Future<List<UserPostModel>> fetchPostsImages(String username) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.userPosts}/$username',
        options: Options(headers: await _getAuthHeaders()),
      );
      final postResponse = UserPostResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return postResponse.results;
    } on DioException catch (e) {
      debugPrint('Error fetching image posts: $e');
      rethrow;
    }
  }

  /// Fetch only posts that have images in polls
  Future<List<UserPostModel>> fetchImagePosts(String username) async {
    final allPosts = await fetchPostsImages(username);

    final filteredPosts = allPosts.where((post) => post.hasPollImages).toList();

    return filteredPosts;
  }

  Future<UserPostModel?> fetchSinglePost(dynamic postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
      final url = '${ApiConstants.userPosts}/$postId';
      debugPrint('🔍 Fetching single post from: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map &&
            data.containsKey('status') &&
            data['status'] == 'success') {
          final postData = data['data'] ?? data;
          return UserPostModel.fromJson(postData);
        }

        final postData = data['data'] ?? data;
        if (postData is List && postData.isNotEmpty) {
          return UserPostModel.fromJson(postData.first);
        } else if (postData is Map<String, dynamic>) {
          return UserPostModel.fromJson(postData);
        }

        debugPrint('⚠️ Unexpected JSON structure for single post: $data');
        return null;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Error fetching single post $postId: ${e.message}');
      debugPrint('❌ Response Status: ${e.response?.statusCode}');
      debugPrint('❌ Response Data: ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Upload image poll
  static Future<Map<String, dynamic>?> uploadImagePoll({
    required String description,
    required String question,
    required List<File> pollOptions,
    required int maxOptions,
    List<String>? labels,
    String votingType = 'single_choice',
    String? authToken,
    Function(double)? onProgress,
    int maxFileSizeMB = 50,
  }) async {
    try {
      // Validation
      if (pollOptions.isEmpty) {
        throw Exception('At least one image is required');
      }
      if (pollOptions.length > maxOptions) {
        throw Exception('Maximum $maxOptions images allowed');
      }

      // Validate file sizes
      for (final image in pollOptions) {
        final fileSizeInBytes = await image.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        if (fileSizeInMB > maxFileSizeMB) {
          throw Exception(
            'Image too large. Maximum size allowed is ${maxFileSizeMB}MB per image',
          );
        }
      }

      // Create FormData
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('description', description),
        MapEntry('question', question),
        const MapEntry('poll_type', "image"),
        MapEntry('voting_type', votingType),
        const MapEntry('max_options', "4"),
      ]);

      // Add poll_options for each image option
      for (int i = 0; i < pollOptions.length; i++) {
        final String labelText = (labels != null && i < labels.length)
            ? labels[i]
            : '';
        formData.fields.add(MapEntry('poll_options', labelText));
      }

      // Add image indices as [0, 1, ...]
      final List<int> indices = List.generate(
        pollOptions.length,
        (index) => index,
      );
      formData.fields.add(MapEntry('image_indices', jsonEncode(indices)));

      // Add original images
      for (int i = 0; i < pollOptions.length; i++) {
        final imageFile = pollOptions[i];
        final String ext = path.extension(imageFile.path).toLowerCase();
        final String subType = ext.startsWith('.') ? ext.substring(1) : 'jpeg';
        final multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
          contentType: MediaType(
            'image',
            subType == 'jpg' ? 'jpeg' : (subType.isEmpty ? 'jpeg' : subType),
          ),
        );
        formData.files.add(MapEntry('images', multipartFile));
      }

      // Headers
      final headers = <String, dynamic>{'Content-Type': 'multipart/form-data'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      // Make request
      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          if (onProgress != null && total != -1) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 413) {
        throw Exception(
          'Image payload too large (413). Payload exceeds server limit.',
        );
      } else if (response.data is Map) {
        final errorMsg = response.data['message'] ??
            response.data['detail'] ??
            response.data['error'] ??
            'Failed to upload poll';
        throw Exception(errorMsg);
      }
      throw Exception('Failed to upload poll. Status: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DioException: ${e.message}');

      if (e.response?.statusCode == 413) {
        throw Exception(
          'Image payload too large (413). Please check server upload limits.',
        );
      } else if (e.response?.data is Map) {
        final errorMsg = e.response?.data['message']?.toString() ??
            e.response?.data['detail']?.toString() ??
            e.response?.data['error']?.toString() ??
            'Failed to create image poll';
        throw Exception(errorMsg);
      } else if (e.response?.data is String &&
          (e.response!.data as String).trim().isNotEmpty) {
        final str = (e.response!.data as String).trim();
        if (str.contains('<html') || str.contains('<HTML')) {
          throw Exception(
            'Server error (${e.response?.statusCode ?? "unknown"})',
          );
        }
        throw Exception(str);
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Please check your internet connection',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Upload timeout. Please try again');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  Future<List<LikeUser>> fetchLikedUsers(dynamic postId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.likePost}/$postId/likes',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> results = data['results'] ?? [];

        return results.map((user) => LikeUser.fromJson(user)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else {
        throw Exception('Failed to load likes. Status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server timeout. Please try again.');
      } else if (e.type == DioExceptionType.badResponse) {
        throw Exception(
          'Failed to load likes. Status: ${e.response?.statusCode}',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error loading likes: $e');
    }
  }

  // Fetch post top-voters users
  static Future<TopVotersModel> getTopVoters({
    required int pollId,
    required int optionId,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      final response = await _dio.get(
        '${ApiConstants.topVoters}/$pollId/options/$optionId/top_voters',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return TopVotersModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to fetch top voters: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('DioException getTopVoters: ${e.message}');
      debugPrint('Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('Error getTopVoters: $e');
      rethrow;
    }
  }

  Future<PollResultResponse> getPollResults(dynamic postId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/posts/$postId/poll_results',
        options: Options(headers: await _getAuthHeaders()),
      );
      return PollResultResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Delete user post
  Future<bool> userDeletePost(dynamic postId) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.deletePost}/$postId/delete',
        options: Options(headers: await _getAuthHeaders()),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error deleting post: $e');
      throw Exception('Error deleting post: $e');
    }
  }

  // ==================== SOCIAL ====================

  /// Get followers list
  Future<List<Map<String, dynamic>>> getFollowersList() async {
    try {
      final response = await _dio.get(
        ApiConstants.chaseList,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final dynamic responseData;
        if (response.data is String) {
          responseData = json.decode(response.data as String);
        } else {
          responseData = response.data;
        }

        // If responseData is directly a list
        if (responseData is List) {
          return responseData
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }

        // If responseData is a map, try to extract the list
        if (responseData is Map) {
          // Try different possible keys
          final list =
              responseData['data'] ??
              responseData['followers'] ??
              responseData['results'];

          // Ensure it's actually a list before converting
          if (list is List) {
            return list
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching followers: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching followers: $e');
      return [];
    }
  }

  /// Get following list
  Future<List<Map<String, dynamic>>> getFollowingList() async {
    try {
      final response = await _dio.get(
        ApiConstants.reChaseList,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final dynamic responseData;
        if (response.data is String) {
          responseData = json.decode(response.data as String);
        } else {
          responseData = response.data;
        }

        // If responseData is directly a list
        if (responseData is List) {
          return responseData
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }

        // If responseData is a map, try to extract the list
        if (responseData is Map) {
          // Try different possible keys
          final list =
              responseData['data'] ??
              responseData['following'] ??
              responseData['results'];

          // Ensure it's actually a list before converting
          if (list is List) {
            return list
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error fetching following: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error fetching following: $e');
      return [];
    }
  }

  /// Get public chase list for a user
  Future<Map<String, dynamic>?> fetchChaseList({
    required String targetUserId,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users/$targetUserId/chase',
        queryParameters: {'page': page},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data as Map);
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching public chase list: $e');
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching public chase list: $e');
      return null;
    }
  }

  /// Get public rechase list for a user
  Future<Map<String, dynamic>?> fetchRechaseList({
    required String targetUserId,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users/$targetUserId/rechase',
        queryParameters: {'page': page},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data as Map);
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error fetching public rechase list: $e');
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching public rechase list: $e');
      return null;
    }
  }

  // Unfriend users
  Future<Map<String, dynamic>> unfriend(dynamic userId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users/unfriend');

      final response = await http.post(
        url,
        headers: await _getAuthHeaders(),
        body: jsonEncode({'user_id': userId?.toString()}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to unfriend user',
          'data': null,
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString(), 'data': null};
    }
  }

  Future<GlobalSearchModel?> globalSearch(
    String query, {
    String? tab,
    int? page,
    int? limit,
    String? publicId,
  }) async {
    try {
      final Map<String, dynamic> params = {'q': query};
      if (tab != null) params['tab'] = tab;
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      if (publicId != null) params['public_id'] = publicId;

      final response = await _dio.get(
        ApiConstants.globalSearch,
        queryParameters: params,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return GlobalSearchModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      return null;
    } on DioException catch (e) {
      _handleDioError(e, defaultMessage: 'Failed to perform search');
      return null;
    }
  }

  Future<RecentSearchResponse> getRecentSearch() async {
    try {
      final response = await _dio.get(
        ApiConstants.recentSearch,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        return RecentSearchResponse.fromJson(jsonData);
      }
      throw Exception('Failed to load recent search: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Error fetching recent search: $e');
    }
  }

  Future<HashtagPostsListModel> searchHashtagPosts(String tag) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/posts/search/hashtag',
        queryParameters: {'tag': tag},
        options: Options(headers: await _getAuthHeaders()),
      );

      return HashtagPostsListModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String username) async {
    try {
      final response = await _dio.post(
        ApiConstants.sendRequest,
        data: {'receiver_username': username},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Error sending friend request: $e');
      return false;
    }
  }

  Future<bool> cancelFriendRequest(dynamic userId) async {
    try {
      final response = await _dio.post(
        ApiConstants.cancelRequest,
        data: FormData.fromMap({'user_id': userId?.toString()}),
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['status'] == 'success';
      }

      return false;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final message = e.response?.data?['message'] ?? 'Unknown error';

      if (statusCode == 404) {
        // "No pending friend request found."
        throw Exception(message);
      }

      throw Exception('Cancel friend request failed: $message');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Check friend request status
  Future<bool> checkFriendRequestStatus(String username) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/friend_requests',
        data: {'receiver_username': username},
        options: Options(
          headers: await _getAuthHeaders(),
          validateStatus: (status) => status == 200 || status == 400,
        ),
      );

      if (response.statusCode == 400) {
        final message = response.data['message'] as String?;
        return message != null &&
            (message.toLowerCase().contains('already following') ||
                message.toLowerCase().contains('already sent'));
      }
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error checking friend request status: ${e.message}');
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        return message != null &&
            (message.toLowerCase().contains('already following') ||
                message.toLowerCase().contains('already sent'));
      }
      return false;
    }
  }

  // Block users
  Future<Map<String, dynamic>> blockUser(dynamic userId) async {
    try {
      final response = await _dio.post(
        ApiConstants.blockUser,
        data: {'user_id': userId?.toString()},
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.data is Map<String, dynamic>) {
        return {'success': true, ...response.data as Map<String, dynamic>};
      }
      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to block user'),
      };
    }
  }

  // Unblock users
  Future<Map<String, dynamic>> unblockUser(dynamic userId) async {
    try {
      final response = await _dio.post(
        ApiConstants.unBlockUser,
        data: {'user_id': userId?.toString()},
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.data is Map<String, dynamic>) {
        return {'success': true, ...response.data as Map<String, dynamic>};
      }
      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to unblock user'),
      };
    }
  }

  // Get blocked users list
  Future<Map<String, dynamic>> getBlockedUsers() async {
    try {
      final response = await _dio.get(
        ApiConstants.blockedUsrsList,
        options: Options(headers: await _getAuthHeaders()),
      );
      return {'success': true, 'data': response.data['data'] as List<dynamic>};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(
          e,
          defaultMessage: 'Failed to get blocked users',
        ),
      };
    }
  }

  // ==================== MESSAGES & GROUP ====================

  Future<Map<String, dynamic>> createGroup({
    required String title,
    required File? profileImage,
    required List<dynamic> members,
    String? category,
    String? privacy,
  }) async {
    try {
      final Map<String, dynamic> map = {'title': title, 'members': members};
      if (category != null) map['category'] = category;
      if (privacy != null) map['privacy'] = privacy;

      if (profileImage != null) {
        final String ext = path.extension(profileImage.path).toLowerCase();
        final String subType = ext.startsWith('.') ? ext.substring(1) : 'jpeg';
        map['group_picture'] = await MultipartFile.fromFile(
          profileImage.path,
          filename: path.basename(profileImage.path),
          contentType: MediaType(
            'image',
            subType == 'jpg' ? 'jpeg' : (subType.isEmpty ? 'jpeg' : subType),
          ),
        );
      }

      final formData = FormData.fromMap(map);

      debugPrint('=== CREATE GROUP REQUEST ===');
      debugPrint('title: $title');
      if (category != null) debugPrint('category: $category');
      if (privacy != null) debugPrint('privacy: $privacy');
      if (profileImage != null) {
        debugPrint('profile_image path: ${profileImage.path}');
      }
      debugPrint('members: $members');
      debugPrint('============================');

      final response = await _dio.post(
        ApiConstants.createGroup,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final chatId =
            data['chat_id'] ??
            data['id'] ??
            data['data']?['id'] ??
            data['data']?['chat_id'];
        return {'success': true, 'chat_id': chatId};
      }
      return {'success': false, 'message': 'Failed to create group'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to create group'),
      };
    }
  }

  // Note: Implemented GET Method Chat List
  Future<List<Map<String, dynamic>>> getChatList() async {
    final response = await getChatListResponse(page: 1);
    return response['results'] as List<Map<String, dynamic>>;
  }

  Future<Map<String, dynamic>> getChatListResponse({
    int page = 1,
    String? nextPageUrl,
  }) async {
    try {
      final String requestUrl;
      if (nextPageUrl != null && nextPageUrl.trim().isNotEmpty) {
        requestUrl =
            ApiConfig.normalizePaginationUrl(nextPageUrl) ??
            '${ApiConstants.chatList}?page=$page';
      } else {
        requestUrl = '${ApiConstants.chatList}?page=$page';
      }

      final response = await _dio.get(
        requestUrl,
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final list = data['results'];
          final rawNext = data['next']?.toString();
          final normalizedNext = ApiConfig.normalizePaginationUrl(rawNext);
          return {
            'results': list is List
                ? List<Map<String, dynamic>>.from(list)
                : <Map<String, dynamic>>[],
            'next': normalizedNext,
            'count': data['count'],
          };
        }
      }
      return {'results': <Map<String, dynamic>>[], 'next': null, 'count': 0};
    } on DioException catch (e) {
      debugPrint('Error fetching chat list: $e');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching chat list: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getGroupPreview({required String slug}) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/g/$slug/preview',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> joinGroup({required String chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chats/group/$chatId/join',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> requestJoinGroup({
    required String chatId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chats/group/$chatId/request_join',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getGroupJoinRequestsList({
    required String chatId,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chats/group/$chatId/join_requests',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> approveGroupJoinRequest({
    required String chatId,
    required String requestId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chats/group/$chatId/join_requests/$requestId/approve',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return {
          'status': 'success',
          'message': 'Join request approved.',
          'data': response.data ?? {},
        };
      }
      return {
        'status': 'error',
        'message': 'Failed to approve join request.',
        'data': {},
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> rejectGroupJoinRequest({
    required String chatId,
    required String requestId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chats/group/$chatId/join_requests/$requestId/reject',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return {
          'status': 'success',
          'message': 'Join request rejected.',
          'data': response.data ?? {},
        };
      }
      return {
        'status': 'error',
        'message': 'Failed to reject join request.',
        'data': {},
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<bool> markChatAsRead({required dynamic chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.markAsRead}/$chatId/read',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>> pinUnpinChat({
    required String chatId,
    required bool isPinned,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.pinUnpinChat}/$chatId/pin',
        data: {'is_pinned': isPinned},
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> muteUnmuteChat({
    required String chatId,
    required bool isMuted,
    DateTime? muteUntil,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.muteUnmuteChat}/$chatId/mute',
        data: {
          'is_muted': isMuted,
          if (muteUntil != null)
            'mute_until': muteUntil.toUtc().toIso8601String(),
        },
        options: Options(headers: await _getAuthHeaders()),
      );
      debugPrint('muteUnmuteChat response: ${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> archiveUnarchiveChat({
    required String chatId,
    required bool isArchived,
  }) async {
    try {
      final formData = FormData.fromMap({'is_archived': isArchived.toString()});

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/$chatId/archive',
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getArchivedList() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chats/archived_list',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> renameGroup({
    required dynamic chatId,
    required String newTitle,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.renameGroup}/$chatId/rename',
        data: {'title': newTitle},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {'success': true, 'new_title': data['new_title']};
      }
      return {'success': false, 'message': 'Failed to rename group'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to rename group'),
      };
    }
  }

  Future<Map<String, dynamic>> favouriteUnfavouriteChat({
    required String chatId,
    required bool isFavourite,
  }) async {
    try {
      final formData = FormData.fromMap({
        'is_favourite': isFavourite.toString(),
      });

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/$chatId/favourite',
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> markChatReadUnread({
    required String chatId,
    required bool isUnread,
  }) async {
    try {
      final formData = FormData.fromMap({'is_unread': isUnread.toString()});

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/$chatId/unread',
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getFavouriteChats() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chats/favourites_list',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> clearChat({required String chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/$chatId/clear',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> deleteChat({required String chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/$chatId/delete',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // upload group profile image
  Future<Map<String, dynamic>> uploadGroupProfile({
    required dynamic chatId,
    required File imageFile,
  }) async {
    final accessToken = await SharedPrefService.getToken();
    try {
      final String ext = path.extension(imageFile.path).toLowerCase();
      final String subType = ext.startsWith('.') ? ext.substring(1) : 'jpeg';

      final formData = FormData.fromMap({
        'group_picture': await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
          contentType: MediaType(
            'image',
            subType == 'jpg' ? 'jpeg' : (subType.isEmpty ? 'jpeg' : subType),
          ),
        ),
      });

      final response = await _dio.post(
        '${ApiConstants.uploadGroupProfile}/$chatId/update_picture',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // add member
  Future<Map<String, dynamic>> addGroupChatMembers({
    required dynamic groupChatId,
    required List<dynamic> members,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.addGroupMembers}/$groupChatId/add_members',
        data: {'members': members},
        options: Options(headers: await _getAuthHeaders()),
      );

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (response.statusCode == 200) {
        final data = responseData as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'],
          'added': data['added'],
        };
      }
      return {'success': false, 'message': 'Failed to add members'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _handleDioError(e, defaultMessage: 'Failed to add members'),
      };
    }
  }

  // remove group member
  Future<Map<String, dynamic>> removeMember({
    required dynamic chatId,
    required dynamic userId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.removeMember}/$chatId/remove_member',
        data: {'user_id': userId?.toString()},
        options: Options(headers: await _getAuthHeaders()),
      );

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      return {'success': true, 'message': responseData['message']};
    } catch (e) {
      return {'success': false, 'message': 'Failed to remove member'};
    }
  }

  // delete group
  Future<Map<String, dynamic>> deleteGroup({required dynamic chatId}) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.deleteGroup}/$chatId/delete',
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.statusCode == 200) {
        return {'message': response.data['message']};
      }
      return {'message': response.data['message'] ?? 'Failed to delete group'};
    } catch (e) {
      return {'message': 'Failed to delete group'};
    }
  }

  // leave group
  Future<Map<String, dynamic>> leaveGroup({required dynamic chatId}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.leaveGroup}/$chatId/leave',
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.statusCode == 200) {
        return {'message': response.data['message']};
      }
      return {'message': response.data['message'] ?? 'Failed to leave group'};
    } catch (e) {
      return {'message': 'Failed to leave group'};
    }
  }

  // Make admin group member
  Future<Map<String, dynamic>> makeAdmin({
    required dynamic chatId,
    required dynamic userId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/chats/group/$chatId/make_admin',
        data: {'user_id': userId?.toString()},
        options: Options(headers: await _getAuthHeaders()),
      );

      debugPrint(
        'Make admin response: ${response.statusCode} ${response.data}',
      );

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      return responseData as Map<String, dynamic>;
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to make admin'};
    }
  }

  Future<Map<String, dynamic>> getGroupChatInfo({
    required dynamic chatId,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/chats/group/$chatId/info',
        options: Options(headers: await _getAuthHeaders()),
      );

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (responseData is Map) {
        final Map<String, dynamic> normalized = Map<String, dynamic>.from(
          responseData,
        );

        // Normalize group details keys to match UI expectations
        normalized['id'] ??=
            int.tryParse(normalized['uuid']?.toString() ?? '') ??
            normalized['id'];
        normalized['profile_url'] ??= normalized['group_picture_url']
            ?.toString();
        normalized['group_picture_url'] ??= normalized['profile_url'];

        // Normalize admins to have 'id' key
        final List<dynamic> admins =
            normalized['admins'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> normalizedAdmins = [];
        final Set<String> adminUuids = {};

        for (final admin in admins) {
          if (admin is Map) {
            final String uuid = (admin['uuid'] ?? admin['id'] ?? '').toString();
            adminUuids.add(uuid);
            normalizedAdmins.add({
              'id': uuid,
              'username': admin['username']?.toString() ?? '',
              'profile_picture_url': admin['profile_picture_url']?.toString(),
            });
          }
        }
        normalized['admins'] = normalizedAdmins;

        // Normalize members to nested structure: { 'is_admin': bool, 'user': { 'id', 'username', 'profile_image' } }
        final List<dynamic> members =
            normalized['members'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> normalizedMembers = [];

        for (final member in members) {
          if (member is Map) {
            final String uuid =
                (member['uuid'] ??
                        member['id'] ??
                        (member['user']?['id'] ?? ''))
                    .toString();
            final bool isAdmin = adminUuids.contains(uuid);
            final String? joinedAt =
                member['joined_at']?.toString() ??
                member['user']?['joined_at']?.toString();
            final bool? isOnline =
                member['is_online'] as bool? ??
                member['user']?['is_online'] as bool?;
            final bool? isBlock =
                member['is_block'] as bool? ??
                member['user']?['is_block'] as bool?;

            normalizedMembers.add({
              'is_admin': isAdmin,
              'joined_at': joinedAt,
              'is_online': isOnline,
              'is_block': isBlock,
              'user': {
                'id': uuid,
                'username':
                    member['username']?.toString() ??
                    (member['user']?['username']?.toString() ?? ''),
                'profile_image':
                    member['profile_picture_url']?.toString() ??
                    member['profile_image']?.toString() ??
                    member['user']?['profile_image']?.toString(),
                'joined_at': joinedAt,
                'is_online': isOnline,
              },
            });
          }
        }
        normalized['members'] = normalizedMembers;

        return normalized;
      }

      return responseData as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // get messages list of private chat
  Future<MessageListModel> getMessageList({
    required dynamic chatId,
    String? nextPageUrl,
  }) async {
    try {
      final requestUrl = nextPageUrl != null && nextPageUrl.trim().isNotEmpty
          ? (ApiConfig.normalizePaginationUrl(nextPageUrl) ?? nextPageUrl)
          : '${ApiConstants.messageList}/$chatId/messages/list';

      final response = await _dio.get(
        requestUrl,
        options: Options(headers: await _getAuthHeaders()),
      );

      return MessageListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        '❌ getMessageList error: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw Exception(
        'Failed to load messages (${e.response?.statusCode}): ${e.response?.data}',
      );
    } catch (e) {
      debugPrint('❌ getMessageList unexpected error: $e');
      throw Exception('Unexpected error while loading messages: $e');
    }
  }

  Future<Map<String, dynamic>> deleteMessage({
    required dynamic chatId,
    required dynamic messageId,
    String deleteType = 'everyone',
  }) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.baseUrl}/chats/$chatId/messages/$messageId',
        data: {
          'delete_type': deleteType,
        },
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'message': response.data?.toString() ?? 'Message deleted'};
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<Map<String, dynamic>> createPrivateChatId({
    required String withUserId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/chats/private',
        data: {'with_user_id': withUserId},
        options: Options(headers: await _getAuthHeaders()),
      );

      debugPrint(
        '✅ createPrivateChat Id [${response.statusCode}]: ${response.data}',
      );

      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        '❌ createPrivateChat DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('❌ createPrivateChat unexpected error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required dynamic chatId,
    required String text,
  }) async {
    try {
      debugPrint('📤 Sending message to server — chatId: $chatId, text: $text');

      final response = await _dio.post(
        '${ApiConstants.sendMessage}/$chatId/messages',
        data: {'text': text},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'data': response.data};
    } on DioException catch (e) {
      debugPrint(
        '❌ sendMessage DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow; // Let provider handle / log the failure
    } catch (e) {
      debugPrint('❌ sendMessage unexpected error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sharePostMessage({
    required dynamic chatId,
    required String sharedPostId,
    required String message,
  }) async {
    try {
      debugPrint(
        '📤 Sharing post — chatId: $chatId, '
        'sharedPostId: $sharedPostId, text: $message',
      );

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/chats/$chatId/messages',
        data: {'text': message, 'shared_post_id': sharedPostId},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return response.data as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Failed to share post'};
    } on DioException catch (e) {
      debugPrint(
        '❌ sharePostMessage DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('❌ sharePostMessage unexpected error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> shareProfileMessage({
    required dynamic chatId,
    required String sharedProfileId,
    required String message,
  }) async {
    try {
      debugPrint(
        '📤 Sharing profile — chatId: $chatId, '
        'sharedProfileId: $sharedProfileId, text: $message',
      );

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/chats/$chatId/messages',
        data: {'text': message, 'shared_profile_id': sharedProfileId},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return response.data as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Failed to share profile'};
    } on DioException catch (e) {
      debugPrint(
        '❌ shareProfileMessage DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('❌ shareProfileMessage unexpected error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> shareGroupMessage({
    required dynamic chatId,
    required String sharedGroupId,
    required String message,
  }) async {
    try {
      debugPrint(
        '📤 Sharing group — chatId: $chatId, '
        'sharedGroupId: $sharedGroupId, text: $message',
      );

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/chats/$chatId/messages',
        data: {'text': message, 'shared_group_id': sharedGroupId},
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return response.data as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Failed to share group'};
    } on DioException catch (e) {
      debugPrint(
        '❌ shareGroupMessage DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('❌ shareGroupMessage unexpected error: $e');
      rethrow;
    }
  }

  Future<int?> addShareCount({required dynamic postId}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/share',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final newShareCount = response.data['data']['new_share_count'] as int;
        return newShareCount;
      }
      return null;
    } on DioException catch (e) {
      debugPrint(
        '❌ addShareCount DioException: '
        'status=${e.response?.statusCode} '
        'body=${e.response?.data} '
        'msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('❌ addShareCount unexpected error: $e');
      rethrow;
    }
  }

  // ==================== PUBLIC PROFILES ====================

  /// Get user public profile
  static Future<PublicProfileModel> getUserPublicProfile(
    dynamic username,
  ) async {
    try {
      final accessToken = await SharedPrefService.getToken();
      debugPrint(
        'getUserPublicProfile request URL: ${ApiConstants.baseUrl}/profile/$username',
      );
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/profile/$username',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          if (mapData.containsKey('status')) {
            if (mapData['status'] == 'success') {
              return PublicProfileModel.fromJson(mapData);
            }
            throw Exception('API returned error: ${mapData['message']}');
          } else {
            // If the response is the direct profile JSON, wrap it
            return PublicProfileModel.fromJson({
              'status': 'success',
              'message': '',
              'data': mapData,
            });
          }
        }
        throw Exception('Invalid response format');
      }
      throw Exception('Failed to load user profile: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint(
        'getUserPublicProfile DioException: ${e.message}, response: ${e.response?.data}',
      );
      throw Exception('Network error: $e');
    }
  }

  // Note: Implemented GET Method User Public Profile Posts
  Future<PublicProfileModel?> getPublicProfilePosts(dynamic userId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.userPosts}/users/$userId/profile',
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return PublicProfileModel.fromJson(response.data['data']);
      } else {
        debugPrint('API Error: ${response.data['message'] ?? 'Unknown error'}');
        return null;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        debugPrint('DioException: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      return null;
    }
  }

  /// Fetch posts with images
  Future<List<UserPostModel>> fetchPostsWithImages(dynamic username) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/profile/$username',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          final postResponse = UserPostResponse.fromJson(
            jsonData['data']['posts'] as Map<String, dynamic>,
          );
          return postResponse.results
              .where((post) => post.isImagePoll)
              .toList();
        }
        throw Exception('API Error: ${jsonData['message']}');
      }
      throw Exception('Failed to load posts: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching posts with images: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Fetch public posts with polls
  Future<List<UserPostModel>> fetchPublicPostsPolls(dynamic username) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/profile/$username',
        options: Options(headers: await _getAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['status'] == 'success') {
          final postResponse = UserPostResponse.fromJson(
            jsonData['data']['posts'] as Map<String, dynamic>,
          );
          return postResponse.results.where((post) => post.isTextPoll).toList();
        }
        throw Exception('API Error: ${jsonData['message']}');
      }
      throw Exception('Failed to load polls: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error fetching posts with polls: $e');
      throw Exception('Network error: $e');
    }
  }

  // ==================== INTERACTIONS ====================

  Future<Map<String, dynamic>> toggleSavePost({required String postId}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/save',
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getSavedPostList({
    int page = 1,
    String? snapshot,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {'page': page};
      if (snapshot != null && snapshot.isNotEmpty) {
        queryParams['snapshot'] = snapshot;
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/posts/saved',
        queryParameters: queryParams,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Toggle post like
  static Future<Map<String, dynamic>> togglePostLike(dynamic postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/posts/$postId/like');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Success',
          'data': data,
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': _errorMessageAuth};
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update like',
      };
    } catch (e) {
      debugPrint('API Error: $e');
      return {'success': false, 'message': _errorMessageNetwork};
    }
  }

  /// Get post likes
  static Future<Map<String, dynamic>> getPostLikes(dynamic postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/posts/$postId/likes');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': 'Failed to fetch likes'};
    } catch (e) {
      debugPrint('API Error: $e');
      return {'success': false, 'message': _errorMessageNetwork};
    }
  }

  // ==================== COMMENTS ====================

  // Note: Implemented GET Method - Get Post Comments
  static Future<Map<String, dynamic>> getPostComments(dynamic postId) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/posts/$postId/comments',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      // Remove the status code check - Dio only returns response for successful status codes
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in getPostComments: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      // Handle 401 Unauthorized
      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      }

      // Handle 404 Not Found (post doesn't exist)
      if (e.response?.statusCode == 404) {
        return {'success': false, 'message': 'Post not found'};
      }

      // Handle connection timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      }

      // Handle no internet connection
      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'message': 'No internet connection'};
      }

      // Generic error with server response
      return {
        'success': false,
        'message':
            e.response?.data['message'] ??
            e.response?.data['detail'] ??
            'Failed to fetch comments',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getPostComments: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // Note: Implemented POST Method - Create Comment
  static Future<Map<String, dynamic>> createComment({
    required dynamic postId,
    required String text,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      // Validate comment text
      if (text.trim().isEmpty) {
        return {'success': false, 'message': 'Comment cannot be empty'};
      }

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/comments',
        data: {'text': text.trim()},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Comment posted successfully',
          'data': response.data,
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to post comment',
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in createComment: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      } else if (e.response?.statusCode == 400) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Invalid comment data',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      } else {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Network error',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in createComment: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  static Future<Map<String, dynamic>> editComment({
    required int commentId,
    required String text,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.patch(
        '${ApiConstants.baseUrl}/comments/$commentId/edit',
        data: {'text': text},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in editComment: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      }

      if (e.response?.statusCode == 404) {
        return {'success': false, 'message': 'Comment not found'};
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      }

      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'message': 'No internet connection'};
      }

      return {
        'success': false,
        'message':
            e.response?.data['message'] ??
            e.response?.data['detail'] ??
            'Failed to edit comment',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in editComment: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // Delete Comment API
  static Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.delete(
        '${ApiConstants.baseUrl}/comments/$commentId/delete',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException in deleteComment: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      }

      if (e.response?.statusCode == 404) {
        return {'success': false, 'message': 'Comment not found'};
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      }

      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'message': 'No internet connection'};
      }

      return {
        'success': false,
        'message':
            e.response?.data['message'] ??
            e.response?.data['detail'] ??
            'Failed to delete comment',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in deleteComment: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  static Future<Map<String, dynamic>> voteOnPollMultiple({
    required dynamic postId,
    required List<Map<String, int>> votes,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/vote',
        data: {"votes": votes},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint("Image vote : $response");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Votes saved successfully',
          'data': response.data['data'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to submit votes',
          'status_code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException submitting votes: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      } else if (e.response?.statusCode == 400) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Invalid vote data',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      } else {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Network error',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting votes: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  static Future<Map<String, dynamic>> voteOnPollSingle({
    required dynamic postId,
    required List<Map<String, int>> votes,
  }) async {
    try {
      final accessToken = await SharedPrefService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Authentication token not found'};
      }

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/posts/$postId/vote',
        data: {"votes": votes},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint("Image vote : $response");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Votes saved successfully',
          'data': response.data['data'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to submit votes',
          'status_code': response.statusCode,
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException submitting votes: ${e.message}');
        print('Response: ${e.response?.data}');
      }

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized. Please login again.',
        };
      } else if (e.response?.statusCode == 400) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Invalid vote data',
        };
      } else if (e.type == DioExceptionType.connectionTimeout) {
        return {
          'success': false,
          'message':
              'Connection timeout. Please check your internet connection',
        };
      } else {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Network error',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting votes: $e');
      }
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // ==================== INSIGHTS ====================

  Future<InsightsModel> getInsightsData() async {
    try {
      final response = await _dio.get(
        ApiConstants.insights,
        options: Options(headers: await _getAuthHeaders()),
      );
      if (response.data is Map<String, dynamic>) {
        return InsightsModel.fromJson(response.data as Map<String, dynamic>);
      }
      return InsightsModel.fromJson(null);
    } on DioException catch (e) {
      throw Exception('Failed to load insights data: ${e.message}');
    }
  }

  // ==================== PRIVACY POLICY ====================

  Future<Map<String, dynamic>> updatePrivacyStatus({
    required String status,
  }) async {
    try {
      final FormData formData = FormData.fromMap({'status': status});

      final Response response = await _dio.post(
        ApiConstants.privacyPolicy,
        data: formData,
        options: Options(headers: await _getAuthHeaders()),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ==================== FEEDBACK ====================

  //   Future<Map<String, dynamic>> submitFeedback({
  //     required String email,
  //     required String subject,
  //     required String category,
  //     required String message,
  //     required int rating,
  //   }) async {
  //     try {
  //       final FormData formData = FormData.fromMap({
  //         'email': email,
  //         'subject': subject,
  //         'category': category,
  //         'message': message,
  //         'rating': rating.toString(),
  //       });

  //       final Response response = await _dio.post(
  //         ApiConstants.feedback,
  //         data: formData,
  //         options: Options(headers: await _getAuthHeaders()),
  //       );

  //       return response.data as Map<String, dynamic>;
  //     } on DioException catch (e) {
  //       throw _handleDioError(e);
  //     }
  //   }
  // }

  Future<Map<String, dynamic>> submitFeedback({
    required String email,
    required String subject,
    required String category,
    required String message,
    required int rating,
    required String reaction,
    File? screenshotFile,
    Map<String, String>? deviceInfo,
  }) async {
    try {
      final deviceData =
          deviceInfo ??
          {
            'browser': 'Flutter App',
            'os': Platform.operatingSystem,
            'screen_resolution':
                '${WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width.toInt()}'
                'x${WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.height.toInt()}',
            'user_agent': 'Polzet Flutter/${Platform.operatingSystemVersion}',
          };

      String? screenshotBase64;
      if (screenshotFile != null) {
        final bytes = await screenshotFile.readAsBytes();
        final base64Str = base64Encode(bytes);
        screenshotBase64 = 'data:image/jpeg;base64,$base64Str';
      }

      final Map<String, dynamic> body = {
        'email': email,
        'subject': subject,
        'category': category,
        'message': message,
        'rating': rating,
        'reaction': reaction,
        'device_info': deviceData,
        if (screenshotBase64 != null) 'screenshot': screenshotBase64,
      };

      final Response response = await _dio.post(
        ApiConstants.feedback,
        data: body,
        options: Options(
          headers: await _getAuthHeaders(),
          contentType: 'application/json',
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      } else if (data is String) {
        if (data.trimLeft().startsWith('<!')) {
          throw Exception('Server returned HTML — check endpoint URL.');
        }
        return jsonDecode(data) as Map<String, dynamic>;
      } else {
        throw Exception('Unexpected response format: ${data.runtimeType}');
      }
    } on DioException catch (e) {
      debugPrint('❌ Status: ${e.response?.statusCode}');
      debugPrint('❌ Error body: ${e.response?.data}');
      throw _handleDioError(e);
    }
  }
}
