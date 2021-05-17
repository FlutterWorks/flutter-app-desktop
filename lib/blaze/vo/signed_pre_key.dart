import 'package:flutter_app/blaze/vo/one_time_pre_key.dart';
import 'package:json_annotation/json_annotation.dart';

part 'signed_pre_key.g.dart';

@JsonSerializable()
class SignedPreKey extends OneTimePreKey {
  SignedPreKey(int keyId, String? pubKey, this.signature)
      : super(keyId, pubKey);

  factory SignedPreKey.fromJson(Map<String, dynamic> json) =>
      _$SignedPreKeyFromJson(json);

  @JsonKey(name: 'signature')
  String signature;

  Map<String, dynamic> toJson() => _$SignedPreKeyToJson(this);
}
