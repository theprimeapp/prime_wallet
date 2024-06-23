// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import '../service/mint_service.dart';
import '../service/wallet_service.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:near_api_flutter/near_api_flutter.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';

import '../interface/coin.dart';
import '../main.dart';
import '../model/seed_phrase_root.dart';
import '../utils/app_config.dart';
import '../utils/rpc_urls.dart';

const nearDecimals = 24;

class NearCoin extends Coin {
  String api;
  String blockExplorer;
  String symbol;
  String default_;
  String image;
  String name;
  String suffix;
  String mintContractID;

  NearCoin({
    this.blockExplorer,
    this.symbol,
    this.default_,
    this.image,
    this.name,
    this.api,
    this.suffix,
    this.mintContractID,
  });

  factory NearCoin.fromJson(Map<String, dynamic> json) {
    return NearCoin(
      api: json['api'],
      blockExplorer: json['blockExplorer'],
      default_: json['default'],
      symbol: json['symbol'],
      image: json['image'],
      name: json['name'],
      suffix: json['suffix'],
      mintContractID: json['mintContractID'],
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
    data['mintContractID'] = mintContractID;

    return data;
  }

  @override
  Future<String> resolveAddress(String address) async {
    return address;
  }

  @override
  String blockExplorer_() {
    return blockExplorer;
  }

  @override
  String default__() {
    return default_;
  }

  @override
  String image_() {
    return image;
  }

  @override
  String name_() {
    return name;
  }

  @override
  String symbol_() {
    return symbol;
  }

  @override
  bool get supportPrivateKey => true;

  @override
  Future<AccountData> fromPrivateKey(String privateKey) async {
    String saveKey = 'nearDetailsPrivate${walletImportType.name}';
    Map<String, dynamic> privateKeyMap = {};

    if (pref.containsKey(saveKey)) {
      privateKeyMap = Map<String, dynamic>.from(jsonDecode(pref.get(saveKey)));
      if (privateKeyMap.containsKey(privateKey)) {
        return AccountData.fromJson(privateKeyMap[privateKey]);
      }
    }

    final results =
        await _NearDerive.fromPrivateKey(privateKey: HEX.decode(privateKey));

    final keys = results.toJson();

    privateKeyMap[privateKey] = keys;

    await pref.put(saveKey, jsonEncode(privateKeyMap));

    return AccountData.fromJson(keys);
  }

  @override
  Future<AccountData> fromMnemonic({String mnemonic}) async {
    String saveKey = 'nearDetails${walletImportType.name}';
    Map<String, dynamic> mnemonicMap = {};

    if (pref.containsKey(saveKey)) {
      mnemonicMap = Map<String, dynamic>.from(jsonDecode(pref.get(saveKey)));
      if (mnemonicMap.containsKey(mnemonic)) {
        return AccountData.fromJson(mnemonicMap[mnemonic]);
      }
    }

    final args = NearDeriveArgs(
      seedRoot: seedPhraseRoot,
    );

    final keys = await compute(calculateNearKey, args);

    mnemonicMap[mnemonic] = keys;

    await pref.put(saveKey, jsonEncode(mnemonicMap));

    return AccountData.fromJson(keys);
  }

  @override
  Future<double> getBalance(bool skipNetworkRequest) async {
    final address = await address_();
    final key = 'nearAddressBalance$address$api';

    final storedBalance = pref.get(key);

    double savedBalance = 0;

    if (storedBalance != null) {
      savedBalance = storedBalance;
    }

    if (skipNetworkRequest) return savedBalance;

    try {
      final request = await post(
        Uri.parse(api),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
          {
            "jsonrpc": "2.0",
            "id": "dontcare",
            "method": "query",
            "params": {
              "request_type": "view_account",
              "finality": "final",
              "account_id": address
            },
          },
        ),
      );

      if (request.statusCode ~/ 100 == 4 || request.statusCode ~/ 100 == 5) {
        throw Exception('Request failed');
      }
      Map decodedData = jsonDecode(request.body);

      final BigInt balance = BigInt.parse(decodedData['result']['amount']);
      final base = BigInt.from(10);

      final balanceInNear = (balance / base.pow(nearDecimals)).toDouble();
      await pref.put(key, balanceInNear);

      return balanceInNear;
    } catch (e) {
      return savedBalance;
    }
  }

  Future<bool> mintToken() async {
    try {
      final account = await getAccount();
      String method = 'ft_mint';
      BigInt mintAmt = MintService.getMint();
      String args = json.encode(
        {
          "account": account.accountId,
          "amount": mintAmt.toString(),
        },
      );

      Contract contract = Contract(mintContractID, account);

      Map result = await contract.callFunction(
        method,
        args,
      );

      result = result['result'];

      if (result == null) {
        return false;
      }

      if (result['final_execution_status'] == 'EXECUTED_OPTIMISTIC') {
        await MintService.deleteMint();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Account> getAccount() async {
    final data = WalletService.getActiveKey(walletImportType).data;
    final getNearDetails = await importData(data);
    final privateKeyPublic = [
      ...HEX.decode(getNearDetails.privateKey),
      ...HEX.decode(getNearDetails.address)
    ];
    final publicKey = PublicKey(
      HEX.decode(
        getNearDetails.address,
      ),
    );
    return Account(
      accountId: getNearDetails.address,
      keyPair: KeyPair(
        PrivateKey(privateKeyPublic),
        publicKey,
      ),
      provider: NearRpcProvider(api),
    );
  }

  @override
  Future<String> transferToken(String amount, String to, {String memo}) async {
    final account = await getAccount();
    final base = BigInt.from(10);

    final amountBig =
        BigInt.from(double.parse(amount)) * base.pow(nearDecimals);
    final trans = await account.sendTokens(
      amountBig,
      to,
    );

    String transactionHash = trans['result']['transaction']['hash'];

    return transactionHash.replaceAll('\n', '');
  }

  @override
  validateAddress(String address) {
    if (address.endsWith(suffix)) {
      return;
    }
    final bytes = HEX.decode(address);
    const exceptedLength = 64;
    const exceptedBytesLength = 32;
    if (address.length != exceptedLength) {
      throw Exception("Near address must have a length of 64");
    }
    if (bytes.length != exceptedBytesLength) {
      throw Exception("Near address must have a decoded byte length of 32");
    }
  }

  @override
  int decimals() {
    return nearDecimals;
  }

  @override
  Future<double> getTransactionFee(String amount, String to) async {
    return 0;
  }

  @override
  Future<String> addressExplorer() async {
    final address = await address_();
    return blockExplorer
        .replaceFirst('/txns/', '/address/')
        .replaceFirst(blockExplorerPlaceholder, address);
  }
}

List<Map<String, dynamic>> getNearBlockChains() {
  List<Map<String, dynamic>> blockChains = [];
  if (enableTestNet) {
    blockChains.add({
      'name': 'NEAR(Testnet)',
      'symbol': 'NEAR',
      'default': 'NEAR',
      'blockExplorer':
          'https://testnet.nearblocks.io/txns/$blockExplorerPlaceholder',
      'image': 'assets/near.png',
      'api': 'https://rpc.testnet.near.org',
      'suffix': '.testnet',
      'mintContractID': 'primewallet.testnet'
    });
  } else {
    blockChains.addAll([
      {
        'name': 'NEAR',
        'symbol': 'NEAR',
        'default': 'NEAR',
        'blockExplorer': 'https://nearblocks.io/txns/$blockExplorerPlaceholder',
        'image': 'assets/near.png',
        'api': 'https://rpc.mainnet.near.org',
        'suffix': '.near',
        'mintContractID': ''
      }
    ]);
  }
  return blockChains;
}

class NearRpcProvider extends RPCProvider {
  final String endpoint;

  NearRpcProvider(this.endpoint) : super(endpoint);
}

class NearDeriveArgs {
  final SeedPhraseRoot seedRoot;

  const NearDeriveArgs({
    this.seedRoot,
  });
}

class _NearDerive {
  static Future<AccountData> fromPrivateKey({List<int> privateKey}) async {
    final publicKey = await ED25519_HD_KEY.getPublicKey(privateKey);

    final address = HEX.encode(publicKey).substring(2);
    return AccountData(
      address: address,
      privateKey: HEX.encode(privateKey),
    );
  }
}

Future calculateNearKey(NearDeriveArgs config) async {
  SeedPhraseRoot seedRoot_ = config.seedRoot;
  KeyData masterKey =
      await ED25519_HD_KEY.derivePath("m/44'/397'/0'", seedRoot_.seed);

  final detail = await _NearDerive.fromPrivateKey(privateKey: masterKey.key);

  return {
    'privateKey': detail.privateKey,
    'address': detail.address,
  };
}
