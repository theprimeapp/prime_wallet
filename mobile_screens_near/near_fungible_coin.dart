import 'dart:convert';
import 'dart:math';

import 'package:cryptowallet/coins/near_coin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:near_api_flutter/near_api_flutter.dart';

import '../main.dart';
import '../service/mint_service.dart';
import '../utils/app_config.dart';

int asciiQuote = 39;
int asciiDobQuote = 34;

class NearFungibleCoin extends NearCoin {
  String contractID;
  int decimals_;

  NearFungibleCoin({
    String api,
    String blockExplorer,
    String symbol,
    String default_,
    String image,
    String name,
    String suffix,
    this.decimals_,
    this.contractID,
  }) : super(
          api: api,
          blockExplorer: blockExplorer,
          symbol: symbol,
          default_: default_,
          image: image,
          name: name,
          suffix: suffix,
        );

  factory NearFungibleCoin.fromJson(Map<String, dynamic> json) {
    return NearFungibleCoin(
      api: json['api'],
      blockExplorer: json['blockExplorer'],
      default_: json['default'],
      symbol: json['symbol'],
      image: json['image'],
      name: json['name'],
      suffix: json['suffix'],
      contractID: json['contractID'],
      decimals_: json['decimals'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['api'] = api;
    data['default'] = default_;
    data['symbol'] = symbol;
    data['name'] = name;
    data['blockExplorer'] = blockExplorer;
    data['image'] = image;
    data['suffix'] = suffix;
    data['contractID'] = contractID;
    data['decimals'] = decimals_;

    return data;
  }

  @override
  int decimals() {
    return decimals_;
  }

  @override
  Future<String> transferToken(String amount, String to, {String memo}) async {
    final account = await getAccount();

    try {
      if (!await _checkRegister(accountID: to)) {
        await _registerToken(accountID: to);
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (_) {}

    String method = 'ft_transfer';
    BigInt tknAmt = BigInt.from(
      double.parse(amount) * pow(10, decimals()),
    );
    String args = json.encode(
      {
        'receiver_id': to,
        'amount': tknAmt.toString(),
      },
    );

    Contract contract = Contract(contractID, account);

    Map result = await contract.callFunction(method, args, BigInt.parse('1'));
    result = result['result'];

    if (result == null) {
      return null;
    }

    if (result['final_execution_status'] == 'EXECUTED_OPTIMISTIC') {
      return result['transaction']['hash'];
    }

    return null;
  }

  @override
  String savedTransKey() {
    return '$contractID$api NearFtDetails';
  }

  Future<bool> _registerToken({String accountID}) async {
    try {
      final account = await getAccount();
      String method = 'storage_deposit';
      String args = json.encode(
        {
          'account_id': accountID,
        },
      );

      Contract contract = Contract(contractID, account);

      await contract.callFunction(
        method,
        args,
        BigInt.parse('1250000000000000000000'),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkRegister({String accountID}) async {
    try {
      final account = await getAccount();
      String method = 'storage_balance_of';
      String args = json.encode(
        {
          'account_id': accountID,
        },
      );

      Contract contract = Contract(contractID, account);

      await contract.callViewFuntion(method, args);

      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<double> getBalance(bool skipNetworkRequest) async {
    final address = await address_();
    final key = 'nearAddressBalance$address$api$contractID';

    final storedBalance = pref.get(key);

    double savedBalance = 0;

    if (storedBalance != null) {
      savedBalance = storedBalance;
    }

    if (skipNetworkRequest) return savedBalance;

    try {
      final account = await getAccount();

      String method = 'ft_balance_of';
      String args = json.encode(
        {
          'account_id': account.accountId,
        },
      );

      Contract contract = Contract(contractID, account);

      var result = await contract.callViewFuntion(method, args);

      if (result['result'] == null) return savedBalance;

      List<int> blRst = List<int>.from(result['result']['result']);

      blRst.removeWhere((int num) => num == asciiQuote || num == asciiDobQuote);

      final toknBal = BigInt.parse(ascii.decode(blRst));

      final base = BigInt.from(10);

      final tknBal = (toknBal / base.pow(decimals())).toDouble();
      await pref.put(key, tknBal);

      return tknBal;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return savedBalance;
    }
  }
}

List<Map<String, dynamic>> walletNearCoin() {
  List<Map<String, dynamic>> blockChains = [];
  if (enableTestNet) {
    blockChains.add(
      {
        'name': 'PRIME',
        'symbol': 'PRM',
        'default': 'NEAR',
        'blockExplorer':
            'https://testnet.nearblocks.io/txns/$blockExplorerPlaceholder',
        'image': 'assets/logo.png',
        'api': 'https://rpc.testnet.near.org',
        'contractID': 'primewallet.testnet',
        'suffix': '.testnet',
        'decimals': 9,
      },
    );
  }

  return blockChains;
}

List<Map<String, dynamic>> getNearFungibles() {
  List<Map<String, dynamic>> blockChains = [];
  if (enableTestNet) {
    blockChains.addAll(
      [
        {
          'name': 'USDC (Devnet)',
          'symbol': 'USDC',
          'default': 'NEAR',
          'blockExplorer':
              'https://testnet.nearblocks.io/txns/$blockExplorerPlaceholder',
          'image': 'assets/wusd.png',
          'api': 'https://rpc.testnet.near.org',
          'contractID':
              '3e2210e1184b45b64c8a434c0a7e7b23cc04ea7eb7a6c3c32520d03d4afcb8af',
          'suffix': '.testnet',
          'decimals': 6,
        },
      ],
    );
  } else {
    blockChains.addAll([
      {
        'name': 'USDC',
        'symbol': 'USDC',
        'default': 'NEAR',
        'blockExplorer': 'https://nearblocks.io/txns/$blockExplorerPlaceholder',
        'image': 'assets/wusd.png',
        'api': 'https://rpc.mainnet.near.org',
        'contractID':
            '17208628f84f5d6ad33f0da3bbbeb27ffcb398eac501a31bd6ad2011e36133a1',
        'suffix': '.near',
        'decimals': 6,
      },
      {
        'name': 'Tether USD',
        'symbol': 'USDT',
        'default': 'NEAR',
        'blockExplorer': 'https://nearblocks.io/txns/$blockExplorerPlaceholder',
        'image': 'assets/usdt.png',
        'api': 'https://rpc.mainnet.near.org',
        'contractID': 'usdt.tether-token.near',
        'suffix': '.near',
        'decimals': 6,
      },
      {
        'name': 'SWEAT',
        'symbol': 'SWEAT',
        'default': 'NEAR',
        'blockExplorer': 'https://nearblocks.io/txns/$blockExplorerPlaceholder',
        'image': 'assets/sweat.png',
        'api': 'https://rpc.mainnet.near.org',
        'contractID': 'token.sweat',
        'suffix': '.near',
        'decimals': 18,
      },
    ]);
  }

  blockChains.addAll(walletNearCoin());
  return blockChains;
}
