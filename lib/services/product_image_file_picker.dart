import 'package:cross_file/cross_file.dart';

import 'product_image_file_picker_stub.dart'
    if (dart.library.io) 'product_image_file_picker_io.dart'
    if (dart.library.html) 'product_image_file_picker_web.dart'
    as platform;

Future<XFile?> pickProductImage() => platform.pickProductImage();
