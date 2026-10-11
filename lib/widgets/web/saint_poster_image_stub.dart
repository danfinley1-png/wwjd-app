import 'package:flutter/material.dart';

Widget buildSaintPosterImage({
  required String url,
  required BoxFit fit,
}) {
  return Image.network(url, fit: fit);
}
