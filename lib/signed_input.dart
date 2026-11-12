import 'package:flutter/services.dart';

/// Keyboard + formatter for whole numbers that may be negative (e.g. "-20").
const signedKeyboard = TextInputType.numberWithOptions(signed: true);
final signedIntFormatter = FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'));
