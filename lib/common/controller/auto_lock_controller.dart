import 'package:fehviewer/common/service/ehconfig_service.dart';
import 'package:fehviewer/generated/l10n.dart';
import 'package:fehviewer/models/index.dart';
import 'package:fehviewer/route/routes.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:get/get.dart';
import 'package:local_auth/auth_strings.dart';

import '../global.dart';

class AutoLockController extends GetxController {
  AutoLock get autoLock => Global.profile.autoLock;
  set autoLock(AutoLock val) =>
      Global.profile = Global.profile.copyWith(autoLock: val);
  final EhConfigService _ehConfigService = Get.find();

  static final IOSAuthMessages iosStrings = IOSAuthMessages(
      cancelButton: S.of(Get.context!).cancel,
      goToSettingsButton: S.of(Get.context!).tab_setting,
      goToSettingsDescription: 'Please set up your Touch & Face ID.',
      lockOut: 'Please reenable your Touch & Face ID');

  static final AndroidAuthMessages androidStrings = AndroidAuthMessages(
    cancelButton: S.of(Get.context!).cancel,
    // signInTitle: '验证',
  );

  /// 最后挂起时间
  int _lastLeaveTime = DateTime.now().millisecondsSinceEpoch;
  int get lastLeaveTime => _lastLeaveTime;
  set lastLeaveTime(int val) {
    _lastLeaveTime = val;
    autoLock = autoLock.copyWith(lastLeaveTime: val);
    Global.saveProfile();
  }

  void resetLastLeaveTime() {
    lastLeaveTime = DateTime.now().millisecondsSinceEpoch + 500;
  }

  bool _isLocking = false;
  bool get isLocking => _isLocking;
  set isLocking(bool val) {
    _isLocking = val;
    autoLock = autoLock.copyWith(isLocking: val);
    Global.saveProfile();
  }

  bool _isResumed = false;

  @override
  void onInit() {
    super.onInit();
  }

  Future<bool> checkBiometrics({String? localizedReason}) async {
    final bool didAuthenticate = await localAuth.authenticate(
      localizedReason: localizedReason ?? '验证以解锁应用',
      iOSAuthStrings: AutoLockController.iosStrings,
      androidAuthStrings: AutoLockController.androidStrings,
    );
    return didAuthenticate;
  }

  void paused() {
    if (!_isLocking) {
      resetLastLeaveTime();
      _isResumed = false;
      logger.v('更新最后离开时间 $lastLeaveTime');
    } else {
      logger.v('保持原离开时间 不更新');
    }
  }

  Future<void> resumed({bool forceLock = false}) async {
    final nowTime = DateTime.now().millisecondsSinceEpoch;
    final subTime = nowTime - lastLeaveTime;
    final autoLockTimeOut = _ehConfigService.autoLockTimeOut.value;

    final _needUnLock =
        autoLockTimeOut >= 0 && (subTime / 1000 > autoLockTimeOut || forceLock);
    logger
        .v('离开时间为: ${subTime}ms  锁定超时为: $autoLockTimeOut  需要解锁: $_needUnLock');

    if (_needUnLock && !_isResumed) {
      _isLocking = true;

      final rult = await Get.toNamed(EHRoutes.unlockPage);
      if (rult is bool) {
        final bool didAuthenticate = rult;
        if (didAuthenticate) {
          localAuth.stopAuthentication();
          _isResumed = true;
          _isLocking = false;
        }
      }
    }
  }
}
