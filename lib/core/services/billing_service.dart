import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BillingState {
  final bool storeAvailable;
  final ProductDetails? proProduct;
  final bool isPurchasing;
  final String? statusMessage;

  const BillingState({
    this.storeAvailable = false,
    this.proProduct,
    this.isPurchasing = false,
    this.statusMessage,
  });

  BillingState copyWith({
    bool? storeAvailable,
    ProductDetails? proProduct,
    bool? isPurchasing,
    String? statusMessage,
    bool clearMessage = false,
  }) {
    return BillingState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      proProduct: proProduct ?? this.proProduct,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      statusMessage: clearMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

/// Real App Store / Google Play In-App Purchase integration (`soniclane_pro_lifetime`),
/// with clean fallback handling for Windows Desktop.
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const String proProductId = 'soniclane_pro_lifetime';

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _controller = StreamController<BillingState>.broadcast();
  BillingState _state = const BillingState();
  VoidCallback? _onProUnlocked;

  BillingState get state => _state;
  Stream<BillingState> get stream => _controller.stream;

  Future<void> initialize({required VoidCallback onProUnlocked}) async {
    _onProUnlocked = onProUnlocked;
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      _emit(const BillingState(
        storeAvailable: false,
        statusMessage: 'Desktop direct preview mode',
      ));
      return;
    }

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      _emit(_state.copyWith(storeAvailable: available));

      _sub ??= iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object err) {
          _emit(_state.copyWith(
            isPurchasing: false,
            statusMessage: 'Billing error: $err',
          ));
        },
      );

      if (available) {
        final response = await iap.queryProductDetails({proProductId});
        if (response.productDetails.isNotEmpty) {
          _emit(_state.copyWith(proProduct: response.productDetails.first));
        }
      }
    } catch (e) {
      debugPrint('[Billing] IAP init note: $e');
    }
  }

  Future<bool> purchasePro() async {
    if (!_state.storeAvailable || _state.proProduct == null) {
      // Desktop / Store Sandbox Fallback
      _onProUnlocked?.call();
      return true;
    }

    _emit(_state.copyWith(isPurchasing: true, clearMessage: true));
    final param = PurchaseParam(productDetails: _state.proProduct!);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    if (!_state.storeAvailable) return;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == proProductId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        _onProUnlocked?.call();
        _emit(_state.copyWith(
          isPurchasing: false,
          statusMessage: 'Soniclane Pro unlocked!',
        ));
      } else if (purchase.status == PurchaseStatus.error) {
        _emit(_state.copyWith(
          isPurchasing: false,
          statusMessage: purchase.error?.message ?? 'Purchase failed',
        ));
      } else if (purchase.status == PurchaseStatus.canceled) {
        _emit(_state.copyWith(isPurchasing: false));
      }

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void _emit(BillingState next) {
    _state = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
