// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:cryptowallet/coins/near_coin.dart';
import 'package:near_api_flutter/near_api_flutter.dart';

class NearNFTCoin extends NearCoin {
  String contractID;
  int decimals_;
  int tokenId;

  NearNFTCoin({
    String api,
    String blockExplorer,
    String symbol,
    String default_,
    String image,
    String name,
    String suffix,
    this.decimals_,
    this.tokenId,
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

  factory NearNFTCoin.fromJson(Map<String, dynamic> json) {
    return NearNFTCoin(
      api: json['api'],
      blockExplorer: json['blockExplorer'],
      default_: json['default'],
      symbol: json['symbol'],
      image: json['image'],
      name: json['name'],
      suffix: json['suffix'],
      contractID: json['contractID'],
      decimals_: json['decimals'],
      tokenId: json['tokenId'],
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
    data['tokenId'] = tokenId;

    return data;
  }

  @override
  Future<double> getBalance(bool skipNetworkRequest) async {
    return 1;
  }

  @override
  Future<String> transferToken(String amount, String to, {String memo}) async {
    final account = await getAccount();

    String method = 'nft_transfer';
    String args = json.encode(
      {
        'token_id': tokenId,
        'receiver_id': to,
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
}
