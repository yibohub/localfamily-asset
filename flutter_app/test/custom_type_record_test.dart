// 自定义类型记录（Asset/Liability 挂 customTypeId）的模型层测试

import 'package:localfamily_asset/models/financial_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Asset 自定义类型', () {
    test('fromJson 保留 custom id 且 type 回退 deposit', () {
      final json = {
        'id': 'a1',
        'record_type': 'asset',
        'asset_type': 'custom_equity',
        'name': '陆联股份',
        'amount': 50000.0,
        'currency': 'CNY',
        'occurrence_date': '2026-09-07T00:00:00',
        'created_at': 1750000000,
        'updated_at': 1750000000,
      };
      final asset = Asset.fromJson(json);

      expect(asset.isCustomType, isTrue);
      expect(asset.customTypeId, 'custom_equity');
      expect(asset.typeId, 'custom_equity');
      // 内置枚举仅回退占位
      expect(asset.type, AssetType.deposit);
    });

    test('custom_type_id 显式字段优先于 asset_type 兼容读取', () {
      final json = {
        'id': 'a2',
        'record_type': 'asset',
        'asset_type': 'custom_equity',
        'custom_type_id': 'custom_equity_2',
        'name': '某股权',
        'amount': 1.0,
        'currency': 'CNY',
        'occurrence_date': '2026-09-07T00:00:00',
        'created_at': 1750000000,
        'updated_at': 1750000000,
      };
      final asset = Asset.fromJson(json);
      expect(asset.customTypeId, 'custom_equity_2');
      expect(asset.typeId, 'custom_equity_2');
    });

    test('自定义记录不视为投资类', () {
      final custom = Asset(
        id: 'x',
        name: '非上市股权',
        type: AssetType.stock, // 内置占位即便为 stock
        customTypeId: 'custom_equity',
        amount: 1.0,
        occurrenceDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(custom.isInvestment, isFalse);
      expect(custom.typeId, 'custom_equity');

      // 内置 stock 仍正常
      final builtin = Asset(
        id: 'y',
        name: '茅台',
        type: AssetType.stock,
        amount: 1.0,
        occurrenceDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(builtin.isInvestment, isTrue);
      expect(builtin.typeId, 'stock');
    });

    test('toJson 输出 typeId 与 custom_type_id', () {
      final asset = Asset(
        id: 'x',
        name: '非上市股权',
        type: AssetType.deposit,
        customTypeId: 'custom_equity',
        amount: 1.0,
        occurrenceDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final json = asset.toJson();
      expect(json['asset_type'], 'custom_equity');
      expect(json['custom_type_id'], 'custom_equity');
    });
  });

  group('Liability 自定义类型', () {
    test('fromJson 保留 custom id 且 type 回退 debt', () {
      final json = {
        'id': 'l1',
        'record_type': 'liability',
        'liability_type': 'custom_borrow',
        'name': '朋友借款',
        'amount': 3000.0,
        'currency': 'CNY',
        'occurrence_date': '2026-09-07T00:00:00',
        'created_at': 1750000000,
        'updated_at': 1750000000,
      };
      final liability = Liability.fromJson(json);

      expect(liability.isCustomType, isTrue);
      expect(liability.customTypeId, 'custom_borrow');
      expect(liability.typeId, 'custom_borrow');
      expect(liability.type, LiabilityType.debt);
    });

    test('自定义记录不视为信用卡', () {
      final custom = Liability(
        id: 'x',
        name: '熟人欠款',
        type: LiabilityType.creditCard, // 占位即便为信用卡
        customTypeId: 'custom_borrow',
        amount: 1.0,
        occurrenceDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(custom.isCreditCard, isFalse);
      expect(custom.typeId, 'custom_borrow');

      final builtin = Liability(
        id: 'y',
        name: '招行卡',
        type: LiabilityType.creditCard,
        amount: 1.0,
        occurrenceDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(builtin.isCreditCard, isTrue);
      expect(builtin.typeId, 'credit_card');
    });
  });
}
